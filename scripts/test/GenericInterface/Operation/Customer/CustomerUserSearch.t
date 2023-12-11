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
use Kernel::GenericInterface::Operation::Customer::CustomerUserSearch;
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
my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

#create user for tests
my @UserIDs;
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
push @UserIDs, $UserID;

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

# create dynamic field object
my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
my @DynamicFieldIDs;

my %DynamicFieldTextConfig = (
        Name       => 'TestText' . $RandomID,
        Label      => 'TestText' . $RandomID,
        FieldOrder => 9990,
        FieldType  => 'Text',
        ObjectType => 'CustomerUser',
        Config     => {
            DefaultValue => '',
            Link         => '',
        },
        Reorder => 1,
        ValidID => 1,
        UserID  => 1,
);

my $FieldTextID = $DynamicFieldObject->DynamicFieldAdd(
    %DynamicFieldTextConfig,
    UserID  => 1,
    Reorder => 1,
);


$Self->True(
    $FieldTextID,
    "Dynamic Field $FieldTextID",
);

$DynamicFieldTextConfig{ID} = $FieldTextID;


push @DynamicFieldIDs, $FieldTextID;

my %DynamicFieldDropdown = (
	Name       => 'TestDropdown' . $RandomID,
        Label      => 'TestDropdown' . $RandomID,
        FieldOrder => 9990,
        FieldType  => 'Dropdown',
        ObjectType => 'CustomerUser',
        Config     => {
            DefaultValue   => '',
            Link           => '',
            PossibleNone   => 0,
            PossibleValues => {
                0 => 'No',
                1 => 'Yes',
            },
            TranslatableValues => 1,
        },
        Reorder => 1,
        ValidID => 1,
        UserID  => 1,

);


my $FieldDropID = $DynamicFieldObject->DynamicFieldAdd(
    %DynamicFieldDropdown,
    UserID  => 1,
    Reorder => 1,
);

$Self->True(
    $FieldDropID,
    "Dynamic Field $FieldDropID",
);

$DynamicFieldDropdown{ID} = $FieldDropID;

push @DynamicFieldIDs, $FieldDropID;

my %DynamicFieldMultiselect = (
	Name       => 'TestMultiselect' . $RandomID,
        Label      => 'TestMultiselect' . $RandomID,
        FieldOrder => 9990,
        FieldType  => 'Multiselect',
        ObjectType => 'CustomerUser',
        Config     => {
            DefaultValue   => '',
            Link           => '',
            PossibleNone   => 0,
            PossibleValues => {
                'a' => 'a',
                'b' => 'b',
                'c' => 'c',
                'd' => 'd',
            },
            TranslatableValues => 1,
        },
        Reorder => 1,
        ValidID => 1,
        UserID  => 1,

);

my $FieldMultiID = $DynamicFieldObject->DynamicFieldAdd(
    %DynamicFieldMultiselect,
    UserID  => 1,
    Reorder => 1,
);

$Self->True(
    $FieldMultiID,
    "Dynamic Field $FieldMultiID",
);

$DynamicFieldMultiselect{ID} = $FieldMultiID;

push @DynamicFieldIDs, $FieldMultiID;

my %DynamicFieldDate = (
	Name       => 'TestDate' . $RandomID,
        Label      => 'TestDate' . $RandomID,
        FieldOrder => 9990,
        FieldType  => 'Date',
        ObjectType => 'CustomerUser',
        Config     => {
            DefaultValue  => 0,
            YearsInFuture => 0,
            YearsInPast   => 0,
            YearsPeriod   => 0,
        },
        Reorder => 1,
        ValidID => 1,
        UserID  => 1,

);

my $FieldDateID = $DynamicFieldObject->DynamicFieldAdd(
    %DynamicFieldDate,
    UserID  => 1,
    Reorder => 1,
);

$Self->True(
    $FieldDateID,
    "Dynamic Field $FieldDateID",
);

$DynamicFieldDate{ID} = $FieldDateID;

push @DynamicFieldIDs, $FieldDateID;

my @TestFieldConfig;

for my $ID (@DynamicFieldIDs) {
	
	push @TestFieldConfig, $DynamicFieldObject->DynamicFieldGet(
		ID	=> $ID,
	);
}

my (@CustomerIDs, @CustomerEntries) = () x 2;

for my $Key(1 .. 4) {

	$RandomID = $Helper->GetRandomNumber();
	$RandomID = $Key + int($RandomID/10**7) + $Key;
	my $Firstname = "Firstname$RandomID";
	my $Lastname  = "Lastname$RandomID";
	my $Login     = $RandomID;

	my $CustomerID = $CustomerUserObject->CustomerUserAdd(
	    Source         => 'CustomerUser',
	    UserFirstname  => $Firstname,
	    UserLastname   => $Lastname,
	    UserCustomerID => "Customer$RandomID",
	    UserLogin      => $Login,
	    UserEmail      => "$Login\@example.com",
	    ValidID        => 1,
	    UserID         => 1,
	);

        push @CustomerIDs, $CustomerID;

        $Self->True(
                $CustomerID,
                "CustomerCompanyAdd() - $CustomerID",
        );
	
	my %Entry = $CustomerUserObject->CustomerUserDataGet(
		User	=> $CustomerID,
	);

	push @CustomerEntries, \%Entry;
	
	my $Success = $DBObject->Do(
		SQL => "insert into dynamic_field_obj_id_name values ($CustomerID, $Entry{UserLogin}, 'CustomerUser')",
	);

	$Self->True(
		$Success,
		"df object created",
	);
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
                        CustomerUserSearch => {
                                Type => 'Customer::CustomerUserSearch',
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
                        CustomerUserSearch => {
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
	UserLogin => $UserLogin,
);
push @UserIDs, $UserID2;

my $Password = $UserLogin;
my $RequesterSessionResult = $RequesterSessionObject->Run(
        WebserviceID => $WebserviceID,
        Invoker      => 'SessionCreate',
        Data         => {
                UserLogin => $UserLogin,
                Password  => $Password,
        },
);


# create backend object and delegates
my $BackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
$Self->Is(
    ref $BackendObject,
    'Kernel::System::DynamicField::Backend',
    'Backend object was created successfully',
);


$BackendObject->ValueSet(
    DynamicFieldConfig => $TestFieldConfig[0],
    ObjectID           => $CustomerIDs[0],
    Value              => 'customer_user1_field1',
    UserID             => 1,
);

$BackendObject->ValueSet(
    DynamicFieldConfig => $TestFieldConfig[1],
    ObjectID           => $CustomerIDs[1],
    Value              => 'customer_user2_field2',
    UserID             => 1,
);

$BackendObject->ValueSet(
    DynamicFieldConfig => $TestFieldConfig[2],
    ObjectID           => $CustomerIDs[2],
    Value              => 'customer_user3_field3',
    UserID             => 1,
);

$BackendObject->ValueSet(
    DynamicFieldConfig => $TestFieldConfig[3],
    ObjectID           => $CustomerIDs[3],
    Value              => '2010-01-01',
    UserID             => 1,
);



my $NewSessionID = $RequesterSessionResult->{Data}->{SessionID};

my $TestCounter = 1;
my @Tests = 
(
       {
                Name            => 'Test ' . $TestCounter++,
                SuccessRequest  => 1,
                RequestData     => {
			SearchDetail => {
				UserLogin => $CustomerEntries[0]{UserLogin},
			},
                },
                ExpectedReturnLocalData => {
                        Data => {
                                CustomerUserIDs => [$CustomerIDs[0]],
                        },
                        Success => 1,
	},
                ExpectedReturnRemoteData => {
                        Data => {
                                CustomerUserIDs => $CustomerIDs[0],
                        },
                        Success => 1,
                },
                Operation => 'CustomerUserSearch',
        },
 
	{
                Name            => 'Test ' . $TestCounter++,
                SuccessRequest  => 1,
                RequestData     => {
			SearchDetail => {
				UserFirstname => $CustomerEntries[1]{UserFirstname},
			},
                },
                ExpectedReturnLocalData => {
                        Data => {
                                CustomerUserIDs => [$CustomerIDs[1]],
                        },
                        Success => 1,
	},
                ExpectedReturnRemoteData => {
                        Data => {
                                CustomerUserIDs => $CustomerIDs[1],
                        },
                        Success => 1,
                },
                Operation => 'CustomerUserSearch',
        },
	{
                Name            => 'Test ' . $TestCounter++,
                SuccessRequest  => 1,
                RequestData     => {
			SearchDetail => {
				UserLastname => $CustomerEntries[2]{UserLastname},
			},
                },
                ExpectedReturnLocalData => {
                        Data => {
                                CustomerUserIDs => [$CustomerIDs[2]],
                        },
                        Success => 1,
	},
                ExpectedReturnRemoteData => {
                        Data => {
                                CustomerUserIDs => $CustomerIDs[2],
                        },
                        Success => 1,
                },
                Operation => 'CustomerUserSearch',
        },
	{
                Name            => 'Test ' . $TestCounter++,
                SuccessRequest  => 1,
                RequestData     => {
			SearchDetail => {
				UserEmail => $CustomerEntries[3]{UserEmail},
			},
                },
                ExpectedReturnLocalData => {
                        Data => {
                                CustomerUserIDs => [$CustomerIDs[3]],
                        },
                        Success => 1,
	},
                ExpectedReturnRemoteData => {
                        Data => {
                                CustomerUserIDs => $CustomerIDs[3],
                        },
                        Success => 1,
                },
                Operation => 'CustomerUserSearch',
        },
 
	{
                Name            => 'Test ' . $TestCounter++,
                SuccessRequest  => 1,
                RequestData     => {
			SearchDetail => {
				OrderByDirection	=> 'Down',
				SortBy			=> 'CustomerUser',
			},
                },
                ExpectedReturnLocalData => {
                        Data => {
                                CustomerUserIDs => [$CustomerIDs[3],$CustomerIDs[2],$CustomerIDs[1],$CustomerIDs[0]],
                        },
                        Success => 1,
	},
                ExpectedReturnRemoteData => {
                        Data => {
                                CustomerUserIDs => [$CustomerIDs[3],$CustomerIDs[2],$CustomerIDs[1],$CustomerIDs[0]],
                        },
                        Success => 1,
                },
                Operation => 'CustomerUserSearch',
        },
	{
                Name            => 'Test Dynamic' . $TestCounter++,
                SuccessRequest  => 1,
                RequestData     => {
			SearchDetail => {
				DynamicField => {
					Name	=> $DynamicFieldTextConfig{Name},
					Equals	=> 'customer_user1_field1',
				},
			},
                },
                ExpectedReturnLocalData => {
                        Data => {
                                CustomerUserIDs =>  [$CustomerIDs[0]],
                        },
                        Success => 1,
		},
                ExpectedReturnRemoteData => {
                        Data => {
                                CustomerUserIDs =>  $CustomerIDs[0],
                        },
                        Success => 1,
                },
                Operation => 'CustomerUserSearch',
        },
	{
                Name            => 'Test Dynamic' . $TestCounter++,
                SuccessRequest  => 1,
                RequestData     => {
			SearchDetail => {
				DynamicField => {
					Name	=> $DynamicFieldDropdown{Name},
					Equals	=> 'customer_user2_field2',
				},
			},
                },
                ExpectedReturnLocalData => {
                        Data => {
                                CustomerUserIDs =>  [$CustomerIDs[1]],
                        },
                        Success => 1,
	},
                ExpectedReturnRemoteData => {
                        Data => {
                                CustomerUserIDs =>  $CustomerIDs[1],
                        },
                        Success => 1,
                },
                Operation => 'CustomerUserSearch',
        },
	{
                Name            => 'Test Dynamic' . $TestCounter++,
                SuccessRequest  => 1,
                RequestData     => {
			SearchDetail => {
				DynamicField => [
					{
						Name	=> $DynamicFieldMultiselect{Name},
						Equals	=> 'customer_user3_field3',
					},
				]
			},
                },
                ExpectedReturnLocalData => {
                        Data => {
                                CustomerUserIDs =>  [$CustomerIDs[2]],
                        },
                        Success => 1,
	},
                ExpectedReturnRemoteData => {
                        Data => {
                                CustomerUserIDs =>  $CustomerIDs[2],
                        },
                        Success => 1,
                },
                Operation => 'CustomerUserSearch',
        },
		
	{
                Name            => 'Test Dynamic' . $TestCounter++,
                SuccessRequest  => 1,
                RequestData     => {
			SearchDetail => {
				DynamicField => 
					{
						Name	=> $DynamicFieldDate{Name},
						Equals	=> '2010-01-01',
					},
			
			},
                },
                ExpectedReturnLocalData => {
                        Data => {
                                CustomerUserIDs =>  [$CustomerIDs[3]],
                        },
                        Success => 1,
	},
                ExpectedReturnRemoteData => {
                        Data => {
                                CustomerUserIDs =>  $CustomerIDs[3],
                        },
                        Success => 1,
                },
                Operation => 'CustomerUserSearch',
        },	
	{
                Name            => 'Test Limit' . $TestCounter++,
                SuccessRequest  => 1,
                RequestData     => {
			SearchDetail => {
				Limit	=> 2,
				OrderByDirection => 'Up',
				
			},
                },
                ExpectedReturnLocalData => {
                        Data => {
                                CustomerUserIDs =>  [$CustomerIDs[3],$CustomerIDs[2]],
                        },
                        Success => 1,
	},
                ExpectedReturnRemoteData => {
                        Data => {
                                CustomerUserIDs =>  [$CustomerIDs[3],$CustomerIDs[2]],
                        },
                        Success => 1,
                },
                Operation => 'CustomerUserSearch',
        }


	 
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
# delete users

my $Success;

for my $UserID (@UserIDs){

	$Success = $DBObject->Do(
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
	    "Group users to User ID $UserID is deleted!"
	);
	$Success = $DBObject->Do(
	    SQL => "DELETE FROM users WHERE id = $UserID",
	);
	$Self->True(
	    $Success,
	    "User with ID $UserID is deleted!"
	);
	
} 
# delete customer users
for my $CustomerUserID (@CustomerIDs){
        my $CustomerUserDelete = $CustomerUserObject->CustomerUserDelete(
                CustomerUserID  => $CustomerUserID,
                UserID          => $UserID,
        );
        $Self->True(
                $CustomerUserDelete,
                "CustomerUserDelete() successful for CustomerUser ID $CustomerUserID",
        );
	$Success = $DBObject->Do(
		SQL => "delete from dynamic_field_value where object_id = $CustomerUserID",
	);
	
	$Self->True(
	    $Success,
	    "Dynamic field value is deleted!"
	);

	$Success = $DBObject->Do(
		SQL => "delete from dynamic_field_obj_id_name where object_id = $CustomerUserID",
	);

	$Self->True(
	    $Success,
	    "Dynamic field object is deleted!"
	);
		
}

for my $ID (@DynamicFieldIDs) {
	$Success = $DBObject->Do(
		SQL => "delete from dynamic_field where id = $ID",
	);
	
	$Self->True(
	    $Success,
	    "Dynamic field with id $ID is deleted!"
	);
}
$CacheObject->CleanUp();
	
1;


