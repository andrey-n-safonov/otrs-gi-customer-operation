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
use Kernel::GenericInterface::Operation::Customer::CustomerUserGet;
my $CustomerUserObject  = $Kernel::OM->Get('Kernel::System::CustomerUser');
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

my $UserObject = $Kernel::OM->Get('Kernel::System::User');

my @Users;
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
$Self->True(
    $UserID,
    'User Add ()',
);

push @Users, $UserID;

#delete old customer users

my @OldCustomerUserIDs = $CustomerUserObject->CustomerSearch(
        CustomerID => '*-Customer-Id-Test',
        ValidID    => 1,
);

for my $CustomerUserID (@OldCustomerUserIDs) {
        $CustomerUserObject->CustomerUserDelete(
                CustomerUserID  => $CustomerUserID,
                UserID          => 1,
	);
}

# create 4 customer users
my ($CustomerUserID1, $CustomerUserID2, $CustomerUserID3, $CustomerUserID4) = () x 4;

my @CustomerUserIDs;

my (@CustomerUserEntries, @CustomerUserRemoteEntries, @CustomerUserIDsWithDF) = () x 3;

for my $Key(1 .. 4) {

	my $UserRand = 'unittest-' . $Key . $Helper->GetRandomID();

        my $customer_create = '$CustomerUserID' . $Key . ' = $CustomerUserObject->CustomerUserAdd(
		Source         => \'CustomerUser\',
		UserFirstname  => \'Firstname Test\' . ' . $Key .  ',
		UserLastname   => \'Lastname Test\' . ' . $Key . ',
		UserCustomerID =>\'' . $UserRand . '\' . \'-Customer-Id-Test\',
		UserLogin      =>\'' . $UserRand . '\',
		UserEmail      =>\'' . $UserRand . '\' . \'-Email@example.com\',
		UserPassword   => \'some_pass\',
		ValidID        => 1,
		UserID         => 1,
	);';
	eval $customer_create;	
		
	
	my $customer_push = 'push @CustomerUserIDs, $CustomerUserID' . $Key;
	eval $customer_push;
	
	$Self->True(
		$CustomerUserIDs[$Key-1],
		"CustomerUser is created with ID $CustomerUserIDs[$Key-1]",
	);
}
 
for my $Key(1 .. 4) {
	
	my %CustomerUserEntry = $CustomerUserObject->CustomerUserDataGet(
		User	=> $CustomerUserIDs[$Key-1],
		UserID	=> $UserID,
	);
	
	$Self->True(
		\%CustomerUserEntry,
		"CustomerUserGet() successful for local CustomerUser",
	);
	
	my %CustomerUserLocalEntry = %CustomerUserEntry;	
	
	push @CustomerUserEntries, \%CustomerUserLocalEntry;
	
	# clean up a mess around the types

	$CustomerUserEntry{ChangeBy} = '' . $CustomerUserEntry{ChangeBy};
	$CustomerUserEntry{CompanyConfig}->{CacheTTL} = '' . $CustomerUserEntry{CompanyConfig}->{CacheTTL};
	$CustomerUserEntry{CompanyConfig}->{CustomerCompanySearchListLimit} = '' . $CustomerUserEntry{CompanyConfig}->{CustomerCompanySearchListLimit};
	$CustomerUserEntry{CompanyConfig}->{Map} = [];
	$CustomerUserEntry{Config}->{CacheTTL} = '' . $CustomerUserEntry{Config}->{CacheTTL};
	$CustomerUserEntry{Config}->{CustomerCompanySupport} = '' . $CustomerUserEntry{Config}->{CustomerCompanySupport};
	$CustomerUserEntry{CompanyConfig}->{Params}->{SearchCaseSensitive} = '' .  $CustomerUserEntry{CompanyConfig}->{Params}->{SearchCaseSensitive};
	$CustomerUserEntry{Config}->{CustomerUserEmailUniqCheck} = '' . $CustomerUserEntry{Config}->{CustomerUserEmailUniqCheck};
	$CustomerUserEntry{Config}->{CustomerUserPostMasterSearchFields} = 'email';
	$CustomerUserEntry{Config}->{CustomerUserSearchListLimit} = '' . $CustomerUserEntry{Config}->{CustomerUserSearchListLimit};
	$CustomerUserEntry{Config}->{Params}->{SearchCaseSensitive} = '' . $CustomerUserEntry{Config}->{Params}->{SearchCaseSensitive};
	$CustomerUserEntry{CustomerCompanyValidID} = '';
	$CustomerUserEntry{Config}->{Selections} = '';
	$CustomerUserEntry{CreateBy} = '' . $CustomerUserEntry{CreateBy};
	
	push @CustomerUserRemoteEntries, \%CustomerUserEntry;
}

# some more work around..

for my $Key (0 .. 3) {

	$CustomerUserRemoteEntries[$Key]{Config}->{Map} = [];
}

# create a customer user entry with dynamic fields

my (@CustomerUserEntriesDF, @CustomerUserRemoteEntriesDF) = () x 2;

for my $Key(0 .. 3) {

	my %EntryDF = $CustomerUserObject->CustomerUserDataGet(
		User		=> $CustomerUserIDs[$Key],
		UserID		=> $UserID,
		DynamicFields	=> 1,
	);
	
	$Self->True(
		\%EntryDF,
		"CustomerUserGet() successful for local CustomerUser $CustomerUserIDs[$Key]  with DF",
	);
	
	my %LocalEntryDF = %EntryDF;

	push @CustomerUserEntriesDF, \%LocalEntryDF;

	# clean up a mess around the types 

	$EntryDF{ChangeBy} = '' . $EntryDF{ChangeBy};
	$EntryDF{CompanyConfig}->{CacheTTL} = '' . $EntryDF{CompanyConfig}->{CacheTTL};
	$EntryDF{CreateBy} = '' . $EntryDF{CreateBy};
	$EntryDF{CustomerCompanyValidID} = '';
	$EntryDF{ValidID} = '' . $EntryDF{ValidID};

	push @CustomerUserRemoteEntriesDF, \%EntryDF;
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
                'Test for CustomerUser Connector using SOAP transport backend.',
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
                        CustomerUserGet => {
                                Type => 'Customer::CustomerUserGet',
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
                        CustomerUserGet => {
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
push @Users, $UserID2;

my $Password = $UserLogin;
my $RequesterSessionResult = $RequesterSessionObject->Run(
        WebserviceID => $WebserviceID,
        Invoker      => 'SessionCreate',
        Data         => {
                UserLogin => $UserLogin,
                Password  => $Password,
        },
);

#create special hash as bad option

my $Bad_hash = {
	
	how_bad => 'very bad',
};


my $NewSessionID = $RequesterSessionResult->{Data}->{SessionID};

my @Tests = 
(
	{
		Name           => 'Empty Request',,
	        SuccessRequest => 1,
	        RequestData    => {
			Data => {}
		},
	        ExpectedReturnLocalData => {
	            Data => {
			Error	=> {
	                   ErrorCode       => 'CustomerUserGet.MissingParameter',
                           ErrorMessage    => "CustomerUserGet: CustomerUserID parameter is missing!",
			}
	            },
	            Success => 1
	        },
	        ExpectedReturnRemoteData => {
	            Data => {
                        Error   => {
	                        ErrorCode       => 'CustomerUserGet.MissingParameter',
                                ErrorMessage    => "CustomerUserGet: CustomerUserID parameter is missing!",
				}
			},
	            Success => 1
	        },
		 Operation => 'CustomerUserGet',

	},

	{
		Name		=> 'Wrong CustomerUserID',
		SuccessRequest => 1,
		RequestData	=> {
			CustomerUserID	=> 'NotCustomerUserID',
		},
		ExpectedReturnLocalData	=> {
			Data => {
				Error => {
					ErrorCode    => 'CustomerUserGet.NotValidCustomerUserID',
					ErrorMessage => 'CustomerUserGet: Could not get CustomerUser data in Kernel::GenericInterface::Operation::Customer::CustomerUserGet::Run()',				
				}
			},
			Success	=> 1
		},
		ExpectedReturnRemoteData => {
			Data => {
				Error => {
					ErrorCode    => 'CustomerUserGet.NotValidCustomerUserID',
					ErrorMessage => 'CustomerUserGet: Could not get CustomerUser data in Kernel::GenericInterface::Operation::Customer::CustomerUserGet::Run()',
				}
			},
			Success => 1
		},
		Operation => 'CustomerUserGet',
	},
	{
		Name		=> 'Wrong structure',
		SuccessRequest => 1,
		RequestData	=> {
			CustomerUserID	=> \%{$Bad_hash},
		},
		ExpectedReturnLocalData	=> {
			Data => {
				Error => {
					ErrorCode    => 'CustomerUserGet.WrongStructure',
	                                ErrorMessage => "CustomerUserGet: Structure for CustomerUserID is not correct!",
				}
			},
			Success	=> 1
		},
		ExpectedReturnRemoteData => {
			Data => {
				Error => {
					ErrorCode    => 'CustomerUserGet.WrongStructure',
                                        ErrorMessage => "CustomerUserGet: Structure for CustomerUserID is not correct!",
				}
			},
			Success => 1
		},
		Operation => 'CustomerUserGet',
	},

	{
		Name		=> 'Test CustomerUser 1',
		SuccessRequest	=> '1',
		RequestData    => {
	            CustomerUserID => $CustomerUserID1,
	        },
	        ExpectedReturnRemoteData => {
	            Success => 1,
	            Data    => {
	                CustomerUser => $CustomerUserRemoteEntries[0],
	            },
	        },
	        ExpectedReturnLocalData => {
	            Success => 1,
	            Data    => {
	                CustomerUser => [ $CustomerUserEntries[0] ],
	            },
	        },
	        Operation => 'CustomerUserGet',
	},
	{
		Name		=> 'Test CustomerUser 2',
		SuccessRequest	=> '1',
		RequestData    => {
	            CustomerUserID => $CustomerUserID2,
	        },
	        ExpectedReturnRemoteData => {
	            Success => 1,
	            Data    => {
	                CustomerUser => $CustomerUserRemoteEntries[1],
	            },
	        },
	        ExpectedReturnLocalData => {
	            Success => 1,
	            Data    => {
	                CustomerUser => [ $CustomerUserEntries[1] ],
	            },
	        },
	        Operation => 'CustomerUserGet',
	},
	{
		Name		=> 'Test CustomerUser 3',
		SuccessRequest	=> '1',
		RequestData    => {
	            CustomerUserID => $CustomerUserID3,
	        },
	        ExpectedReturnRemoteData => {
	            Success => 1,
	            Data    => {
	                CustomerUser => $CustomerUserRemoteEntries[2],
	            },
	        },
	        ExpectedReturnLocalData => {
	            Success => 1,
	            Data    => {
	                CustomerUser => [ $CustomerUserEntries[2] ],
	            },
	        },
	        Operation => 'CustomerUserGet',
	},
	{
		Name		=> 'Test CustomerUser 4',
		SuccessRequest	=> '1',
		RequestData    => {
	            CustomerUserID => $CustomerUserID4,
	        },
	        ExpectedReturnRemoteData => {
	            Success => 1,
	            Data    => {
	                CustomerUser => $CustomerUserRemoteEntries[3],
	            },
	        },
	        ExpectedReturnLocalData => {
	            Success => 1,
	            Data    => {
	                CustomerUser => [ $CustomerUserEntries[3] ],
	            },
	        },
	        Operation => 'CustomerUserGet',
	},

	{
		Name		=> 'Test CustomerUser 1 with DF',
		SuccessRequest	=> '1',
		RequestData    => {
		    CustomerUserID => $CustomerUserID1,
		    DynamicFields  => 1,
	       },
	        ExpectedReturnRemoteData => {
	            Success => 1,
	            Data    => {
	               CustomerUser => $CustomerUserRemoteEntriesDF[0],
		            },
	        },
	        ExpectedReturnLocalData => {
	            Success => 1,
	            Data    => {
	                CustomerUser => [ $CustomerUserEntriesDF[0] ],
	            },
	        },
	        Operation => 'CustomerUserGet',
	},
	
	{
		Name		=> 'Test CustomerUser 2 with DF',
		SuccessRequest	=> '1',
		RequestData    => {
	           CustomerUserID => $CustomerUserID2,
		    DynamicFields  => 1,
	       },
	        ExpectedReturnRemoteData => {
	            Success => 1,
	            Data    => {
	               CustomerUser => $CustomerUserRemoteEntriesDF[1],
		            },
	        },
	        ExpectedReturnLocalData => {
	            Success => 1,
	            Data    => {
	                CustomerUser => [ $CustomerUserEntriesDF[1] ],
	            },
	        },
	        Operation => 'CustomerUserGet',
	},
	{
		Name		=> 'Test CustomerUser 3 with DF',
		SuccessRequest	=> '1',
		RequestData    => {
	           CustomerUserID => $CustomerUserID3,
		    DynamicFields  => 1,
	       },
	        ExpectedReturnRemoteData => {
	            Success => 1,
	            Data    => {
	               CustomerUser => $CustomerUserRemoteEntriesDF[2],
		            },
	        },
	        ExpectedReturnLocalData => {
	            Success => 1,
	            Data    => {
	                CustomerUser => [ $CustomerUserEntriesDF[2] ],
	            },
	        },
	        Operation => 'CustomerUserGet',
	},
	{
		Name		=> 'Test CustomerUser 4 with DF',
		SuccessRequest	=> '1',
		RequestData    => {
	           CustomerUserID => $CustomerUserID4,
		    DynamicFields  => 1,
	       },
	        ExpectedReturnRemoteData => {
	            Success => 1,
	            Data    => {
	               CustomerUser => $CustomerUserRemoteEntriesDF[3],
		            },
	        },
	        ExpectedReturnLocalData => {
	            Success => 1,
	            Data    => {
	                CustomerUser => [ $CustomerUserEntriesDF[3] ],
	            },
	        },
	        Operation => 'CustomerUserGet',
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
	if ( exists($RequesterResult->{Data}->{CustomerUser}) ) { 
		$RequesterResult->{Data}->{CustomerUser}->{CompanyConfig}->{Map} = [];
		$RequesterResult->{Data}->{CustomerUser}->{Config}->{Map} = [];
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
 
# delete customer users
for my $CustomerUserID (@CustomerUserIDs){
	my $CustomerUserDelete = $CustomerUserObject->CustomerUserDelete(
		CustomerUserID	=> $CustomerUserID,
		UserID		=> $UserID,
	);

	$Self->True(
		$CustomerUserDelete,
		"CustomerUserDelete() successful for CustomerUser ID $CustomerUserID",
	);
}

# delete user
my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
for my $UserID (@Users) { 
	my $Success = $DBObject->Do(
	    SQL => "DELETE FROM user_preferences WHERE user_id = $UserID",
	);
	$Self->True(
	    $Success,
	    "User preference referenced to User ID $UserID is deleted!"
	);
	$Success = $DBObject->Do(
		SQL => "delete from group_user where user_id = $UserID",
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


