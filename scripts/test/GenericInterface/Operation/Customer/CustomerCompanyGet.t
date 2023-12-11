# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2021 Centuran Consulting, https://centuran.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

## no critic (Modules::RequireExplicitPackage)
use strict;
use warnings;
use utf8;
use vars (qw($Self));
use Kernel::GenericInterface::Debugger;
use Kernel::GenericInterface::Operation::Session::SessionCreate;
use Kernel::GenericInterface::Operation::Customer::CustomerCompanyGet;
my $CustomerCompanyObject  = $Kernel::OM->Get('Kernel::System::CustomerCompany');
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
my $CacheObject	 = $Kernel::OM->Get('Kernel::System::Cache');

    $ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

# Skip SSL certificate verification.
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        SkipSSLVerify => 1,
    },
);

my $Helper      = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $RandomID = $Helper->GetRandomNumber();
my @Users;
my $UserObject = $Kernel::OM->Get('Kernel::System::User');


#create user for tests
my $UserID = $UserObject->UserAdd(
        UserFirstname   => 'Test',
        UserLastname    => 'User',
        UserLogin       => 'TestUser' . $RandomID,
        UserPw          => 'some-pass',
        UserEmail       => 'test' . $RandomID . 'email@example.com',
        ValidID         => 1,
        ChangeUserID    => 1,
);

push @Users, $UserID;

$Self->True(
    $UserID,
    'User Add ()',
);


my @CustomerCompanyIDs;

my (@CustomerCompanyEntries, @CustomerCompanyRemoteEntries, @CustomerCompanyEntriesDF) = () x 3;

for my $Key(1 .. 4) {

	my $CompanyRand = 'Example-Customer-Company' . $Key . $Helper->GetRandomID();

	my $CustomerID = $CustomerCompanyObject->CustomerCompanyAdd(
	        CustomerID             => $CompanyRand . $Key,
	        CustomerCompanyName    => $CompanyRand . ' Inc-test',
	        CustomerCompanyStreet  => 'Some Street',
	        CustomerCompanyZIP     => '12345',
	        CustomerCompanyCity    => 'Some city',
	        CustomerCompanyCountry => 'USA',
	        CustomerCompanyURL     => 'http://example.com',
	        CustomerCompanyComment => 'some comment',
	        ValidID                => 1,
	        UserID                 => 1,
	);
	
	push @CustomerCompanyIDs, $CustomerID;
	
	$Self->True(
		$CustomerID,
		"CustomerCompanyAdd() - $CustomerID",
	);

	my %Entry = $CustomerCompanyObject->CustomerCompanyGet(
		CustomerID => $CustomerID,
		UserID	   => $UserID,
	);
	
	$Self->True(
		\%Entry,
		"CustomerCompanyGet() - successful",
	);

	$Self->Is(
		$Entry{CustomerCompanyName},
	        "$CompanyRand Inc-test",
	        "CustomerCompanyGet() - 'Company Name'",
	);
	
	my %LocalEntry = %Entry;
	push @CustomerCompanyEntries, \%LocalEntry;
	
	# workaround types

	$Entry{ChangeBy} = '' . $Entry{ChangeBy};
        $Entry{Config}->{CacheTTL} = '' . $Entry{Config}->{CacheTTL};
	$Entry{Config}->{CustomerCompanySearchListLimit} = '' . $Entry{Config}->{CustomerCompanySearchListLimit};
        $Entry{Config}->{Params}->{SearchCaseSensitive} = '' . $Entry{Config}->{Params}->{SearchCaseSensitive};
        $Entry{CreateBy} = '' . $Entry{CreateBy};

	push @CustomerCompanyRemoteEntries, \%Entry;

	# create entries with dynamic fields

	my %EntryDF = $CustomerCompanyObject->CustomerCompanyGet(
		CustomerID	=> $CustomerID,
		UserID		=> $UserID,
		DynamicFields	=> 1,
	);

	$Self->True(
		\%EntryDF,
		"CustomerCompanyGet() - successful",
	);

	$Self->Is(
		$EntryDF{CustomerCompanyName},
	        "$CompanyRand Inc-test",
	        "CustomerCompanyGet() - 'Company Name'",
	); 

	push @CustomerCompanyEntriesDF, \%EntryDF;

}

#skip field

for my $Key (0 .. 3) {
	delete $CustomerCompanyRemoteEntries[$Key]{Config}->{Map};
}

# create web service

my $WebserviceName = '-Test-' . $RandomID;
my $WebserviceObject = $Kernel::OM->Get('Kernel::System::GenericInterface::Webservice');
$Self->Is(
        'Kernel::System::GenericInterface::Webservice',
        ref $WebserviceObject,
        "Create web service object"
);
my $WebserviceID = $WebserviceObject->WebserviceAdd(
    Name   => $WebserviceName,
    Config => {
        Debugger => {
            DebugThreshold => 'debug',
        },
        Provider => {
            Transport => {
                Type => '',
            },
        },
    },
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $WebserviceID,
    'Added web service'
);
my $Host = $Helper->GetTestHTTPHostname();
my $RemoteSystem =
    $ConfigObject->Get('HttpType')
    . '://'
    . $Host
    . '/'
    . $ConfigObject->Get('ScriptAlias')
    . '/nph-genericinterface.pl/WebserviceID/'
    . $WebserviceID;
my $WebserviceConfig = { 
        Description =>
                'Test for CustomerCompany Connector using SOAP transport backend.',
        Debugger => {
                DebugThreshold  => 'debug',
                TestMode        => 1,
        },
        Provider => {
                Transport => {
                        Type => 'HTTP::SOAP',
                        Config => {
                                MaxLenght => 10000000,
                                NameSpace => 'http://otrs.org/SoapTestInterface/',
                                Endpoint  => $RemoteSystem,
                        },
                },
                Operation => {
                        CustomerCompanyGet => {
                                Type => 'Customer::CustomerCompanyGet',
                        },
                        SessionCreate => {
                                Type => 'Session::SessionCreate',
                        },
                },
},
        Requester => {
                Transport => {
                        Type    => 'HTTP::SOAP',
                        Config  => {
                                NameSpace => 'http://otrs.org/SoapTestInterface/',
                                Encodiong => 'UTF-8',
                                Endpoint  =>  $RemoteSystem,
                                Timeout   =>  120,
                        },
                },
                Invoker => {
                        CustomerCompanyGet => {
                                Type => 'Test::TestSimple',
                        },
                        SessionCreate => {
                                Type => 'Test::TestSimple',
                        },
                },
        },

};

# update web-service with real config
# the update is needed because we are using
# the WebserviceID for the Endpoint in config

my $WebserviceUpdate = $WebserviceObject->WebserviceUpdate(
	ID      => $WebserviceID,
        Name    => $WebserviceName,
        Config  => $WebserviceConfig,
        ValidID => 1,
        UserID  => $UserID,
);

$Self->True(
        $WebserviceUpdate,
        "Updated web service $WebserviceID - $WebserviceName" 
);
my $RequesterSessionObject = $Kernel::OM->Get('Kernel::GenericInterface::Requester');
$Self->True(
        'Kernel::GenericInterface::Requester',
        ref $RequesterSessionObject,
        'SessionID - Create requester object'
);
my $UserLogin = $Helper->TestUserCreate(
        Groups => ['admin','users'],
);
my $UserID2 = $UserObject->UserLookup(
	UserLogin => $UserLogin
);

push @Users, $UserID;

my $Password = $UserLogin;
my $RequesterSessionResult = $RequesterSessionObject->Run(
        WebserviceID => $WebserviceID,
        Invoker      => 'SessionCreate',
        Data         => {
                UserLogin => $UserLogin,
                Password  => $Password,
        },
);

my $DebuggerObject = Kernel::GenericInterface::Debugger->new(
        DebuggerConfig => {
                DebugThreshold  => 'debug',
                TestMode        => 1,
        },
        WebserviceID            => $WebserviceID,
        CommunicationType       => 'Provider',
);
$Self->Is(
        ref $DebuggerObject,
        'Kernel::GenericInterface::Debugger',
        'DebuggerObject instantiate correctly'
);

my %bad_hash = (
	how_bad => 'very bad',
);

my @Tests = (
	
	{
                Name           => 'Empty Request',,
                SuccessRequest => 1,
                RequestData    => {
                        Data => {}
                },
                ExpectedReturnLocalData => {
                    Data => {
                        Error   => {
                           ErrorCode       => 'CustomerCompanyGet.MissingParameter',
                           ErrorMessage    => "CustomerCompanyGet: CustomerID parameter is missing!",
                        }
                    },
                    Success => 1
                },
		ExpectedReturnRemoteData => {
	                Data => {
	                        Error   => {
	                                ErrorCode       => 'CustomerCompanyGet.MissingParameter',
	                                ErrorMessage    => "CustomerCompanyGet: CustomerID parameter is missing!",
	                                }
	                        },
	                Success => 1
	                },
                Operation => 'CustomerCompanyGet',

	},
        {
                Name            => 'Wrong CustomerID',
                SuccessRequest => 1,
                RequestData     => {
                        CustomerID  => 'NotCustomerID',
                },
                ExpectedReturnLocalData => {
                        Data => {
                                Error => {
                                        ErrorCode    => 'CustomerCompanyGet.NotValidCustomerID',
                                        ErrorMessage => 'CustomerCompanyGet: Could not get CustomerCompany data in Kernel::GenericInterface::Operation::Customer::CustomerCompanyGet::Run()',
                                }
                        },
                        Success => 1
                },
                ExpectedReturnRemoteData => {
                        Data => {
                                Error => {
                                        ErrorCode    => 'CustomerCompanyGet.NotValidCustomerID',
                                        ErrorMessage => 'CustomerCompanyGet: Could not get CustomerCompany data in Kernel::GenericInterface::Operation::Customer::CustomerCompanyGet::Run()',
                                }
                        },
                        Success => 1
                },
                Operation => 'CustomerCompanyGet',
        },
        {
                Name            => 'Wrong structure',
                SuccessRequest => 1,
                RequestData     => {
                        CustomerID  => \%bad_hash,
                },
                ExpectedReturnLocalData => {
                        Data => {
				Error => {
                                        ErrorCode    => 'CustomerCompanyGet.WrongStructure',
                                        ErrorMessage => "CustomerCompanyGet: Structure for CustomerID is not correct!",
                                }
                        },
                        Success => 1
                },
                ExpectedReturnRemoteData => {
                        Data => {
                                Error => {
                                        ErrorCode    => 'CustomerCompanyGet.WrongStructure',
                                        ErrorMessage => "CustomerCompanyGet: Structure for CustomerID is not correct!",
                                }
                        },
                        Success => 1
                },
                Operation => 'CustomerCompanyGet',
	},
 
	{
                Name            => 'Test CustomerCompany 1',
                SuccessRequest  => '1',
                RequestData    => {
                    CustomerID => $CustomerCompanyIDs[0],
                },
                ExpectedReturnRemoteData => {
                    Success => 1,
                    Data    => {
                        CustomerCompany => $CustomerCompanyRemoteEntries[0],
                    },
                },
                ExpectedReturnLocalData => {
                    Success => 1,
                    Data    => {
                        CustomerCompany => [ $CustomerCompanyEntries[0] ],
                    },
                },
                Operation => 'CustomerCompanyGet',
        },
	{
                Name            => 'Test CustomerCompany 2',
                SuccessRequest  => '1',
                RequestData    => {
                    CustomerID => $CustomerCompanyIDs[1],
                },
                ExpectedReturnRemoteData => {
                    Success => 1,
                    Data    => {
                        CustomerCompany => $CustomerCompanyRemoteEntries[1],
                    },
                },
                ExpectedReturnLocalData => {
                    Success => 1,
                    Data    => {
                        CustomerCompany => [ $CustomerCompanyEntries[1] ],
                    },
                },
                Operation => 'CustomerCompanyGet',
        },
	
	{
                Name            => 'Test CustomerCompany 3',
                SuccessRequest  => '1',
                RequestData    => {
                    CustomerID => $CustomerCompanyIDs[2],
                },
                ExpectedReturnRemoteData => {
                    Success => 1,
                    Data    => {
                        CustomerCompany => $CustomerCompanyRemoteEntries[2],
                    },
                },
                ExpectedReturnLocalData => {
                    Success => 1,
                    Data    => {
                        CustomerCompany => [ $CustomerCompanyEntries[2] ],
                    },
                },
                Operation => 'CustomerCompanyGet',
        },

	{
                Name            => 'Test CustomerCompany 4',
                SuccessRequest  => '1',
                RequestData    => {
                    CustomerID => $CustomerCompanyIDs[3],
                },
                ExpectedReturnRemoteData => {
                    Success => 1,
                    Data    => {
                        CustomerCompany => $CustomerCompanyRemoteEntries[3],
                    },
                },
                ExpectedReturnLocalData => {
                    Success => 1,
                    Data    => {
                        CustomerCompany => [ $CustomerCompanyEntries[3] ],
                    },
                },
                Operation => 'CustomerCompanyGet',
        },
	{
                Name            => 'Test CustomerCompany 1 with DF',
                SuccessRequest  => '1',
                RequestData    => {
                    CustomerID		=> $CustomerCompanyIDs[0],
		    DynamicFields	=> 1,
                },
                ExpectedReturnRemoteData => {
                    Success => 1,
                    Data    => {
                        CustomerCompany => $CustomerCompanyEntriesDF[0],
                    },
                },
                ExpectedReturnLocalData => {
                    Success => 1,
                    Data    => {
                        CustomerCompany => [  $CustomerCompanyEntriesDF[0] ],
                    },
                },
                Operation => 'CustomerCompanyGet',
        },

	{
                Name            => 'Test CustomerCompany 2 with DF',
                SuccessRequest  => '1',
                RequestData    => {
                    CustomerID		=> $CustomerCompanyIDs[1],
		    DynamicFields	=> 1,
                },
                ExpectedReturnRemoteData => {
                    Success => 1,
                    Data    => {
                        CustomerCompany => $CustomerCompanyEntriesDF[1],
                    },
                },
                ExpectedReturnLocalData => {
                    Success => 1,
                    Data    => {
                        CustomerCompany => [  $CustomerCompanyEntriesDF[1] ],
                    },
                },
                Operation => 'CustomerCompanyGet',
        },

	{
                Name            => 'Test CustomerCompany 3 with DF',
                SuccessRequest  => '1',
                RequestData    => {
                    CustomerID		=> $CustomerCompanyIDs[2],
		    DynamicFields	=> 1,
                },
                ExpectedReturnRemoteData => {
                    Success => 1,
                    Data    => {
                        CustomerCompany => $CustomerCompanyEntriesDF[2],
                    },
                },
                ExpectedReturnLocalData => {
                    Success => 1,
                    Data    => {
                        CustomerCompany => [  $CustomerCompanyEntriesDF[2] ],
                    },
                },
                Operation => 'CustomerCompanyGet',
        },

	{
                Name            => 'Test CustomerCompany 4 with DF',
                SuccessRequest  => '1',
                RequestData    => {
                    CustomerID		=> $CustomerCompanyIDs[3],
		    DynamicFields	=> 1,
                },
                ExpectedReturnRemoteData => {
                    Success => 1,
                    Data    => {
                        CustomerCompany => $CustomerCompanyEntriesDF[3],
                    },
                },
                ExpectedReturnLocalData => {
                    Success => 1,
                    Data    => {
                        CustomerCompany => [  $CustomerCompanyEntriesDF[3] ],
                    },
                },
                Operation => 'CustomerCompanyGet',
        },

);
my $NewSessionID = $RequesterSessionResult->{Data}->{SessionID};


for my $Test (@Tests) {
	my $LocalObject = "Kernel::GenericInterface::Operation::Customer::$Test->{Operation}"->new(
	        DebuggerObject => $DebuggerObject,
	        WebserviceID   => $WebserviceID,
	);
	$Self->Is(
		"Kernel::GenericInterface::Operation::Customer::$Test->{Operation}",
	        ref $LocalObject,
	        "$Test->{Name} - Create local object",
	);
	my $LocalResult = $LocalObject->Run(
	        WebserviceID => $WebserviceID,
	        Invoker      => $Test->{Operation},
	        Data         => { 
	            UserLogin => $UserLogin,
	            Password  => $Password,
	            %{ $Test->{RequestData} },
	        },
	);
	$Self->Is(
	        'HASH',
	        ref $LocalResult,
	        "$Test->{Name} - Local result structure is valid"
	);
	my $RequesterObject = $Kernel::OM->Get('Kernel::GenericInterface::Requester');
	$Self->Is(
	        'Kernel::GenericInterface::Requester',
	        ref $RequesterObject,
	        "$Test->{Name} - Create requester object"
	    );

	my $RequesterResult = $RequesterObject->Run(
	        WebserviceID => $WebserviceID,
	        Invoker      => $Test->{Operation},
	        Data         => {
	            SessionID => $NewSessionID,
	            %{ $Test->{RequestData} },
	        }
	);
	$Self->Is(
	        'HASH',
	        ref $RequesterResult,
	        "$Test->{Name} - Requester result structure is valid",

	);
	$Self->Is(
	        $RequesterResult->{Success},
	        $Test->{SuccessRequest},
	        "$Test->{Name} - Requester successful result $RequesterResult->{ErrorMessage}",
	);
        # remove ErrorMessage parameter from direct call
	# result to be consistent with SOAP call result
	
	if ( $LocalResult->{ErrorMessage} ) {
	        delete $LocalResult->{ErrorMessage};
	}
	if ( exists($RequesterResult->{Data}->{CustomerCompany}) ) { 
		$RequesterResult->{Data}->{CustomerCompany}->{Config}->{Map} = [];
	}

	$Self->IsDeeply(
	        $RequesterResult,
	        $Test->{ExpectedReturnRemoteData},
	        "$Test->{Name} - Requester success status (needs configured and running webserver)"
	);

	if ( $Test->{ExpectedReturnLocalData} ) {
        $Self->IsDeeply(
            $LocalResult,
            $Test->{ExpectedReturnLocalData},
            "$Test->{Name} - Local result matched with expected local call result.",
        );
	
	}
	else {
	        $Self->IsDeeply(
	            $LocalResult,
	            $Test->{ExpectedReturnRemoteData},
	            "$Test->{Name} - Local result matched with remote result.",
	        );
	} 

}
# clean up

my $WebserviceDelete = $WebserviceObject->WebserviceDelete(
	ID	=>	$WebserviceID,
	UserID	=>	$UserID,
);

$Self->True(
	$WebserviceDelete,
	"Deleted web service $WebserviceID",
);
 
# delete customer company
for my $CustomerID (@CustomerCompanyIDs){
	my $CustomerCompanyDelete = $CustomerCompanyObject->CustomerCompanyDelete(
		CustomerID	=> $CustomerID,
		UserID		=> $UserID,
	);

	$Self->True(
		$CustomerCompanyDelete,
		"CustomerCompanyDelete() - $CustomerID",
	);
}


# delete users

my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

for my $UserID (@Users) {
	my $Success = $DBObject->Do(
	    SQL => "DELETE FROM user_preferences WHERE user_id = $UserID",
	);
	$Self->True(
	    $Success,
	    "User preference referenced to User ID $UserID is deleted!"
	);
	
	my $Success = $DBObject->Do(
	    SQL => "DELETE FROM group_user WHERE user_id = $UserID",
	);
	$Self->True(
	    $Success,
	    "Group user referenced to User ID $UserID is deleted!"
	);
	
	$Success = $DBObject->Do(
	    SQL => "DELETE FROM users WHERE id = $UserID",
	);
	$Self->True(
	    $Success,
	    "User with ID $UserID is deleted!"
	);
}
$CacheObject->CleanUp();
	
1;


