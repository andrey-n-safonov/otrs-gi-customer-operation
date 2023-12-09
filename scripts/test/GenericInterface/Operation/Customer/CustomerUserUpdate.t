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
use Kernel::System::VariableCheck qw(:all);
use Kernel::GenericInterface::Debugger;
use Kernel::GenericInterface::Operation::Session::SessionCreate;
use Kernel::GenericInterface::Operation::Customer::CustomerUserUpdate;
my $CustomerUserObject  = $Kernel::OM->Get('Kernel::System::CustomerUser');
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
my $CacheObject  = $Kernel::OM->Get('Kernel::System::Cache');

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
my @DynamicFieldIDs;

$Helper->ConfigSettingChange(
    Valid => 1,
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

# disable SessionCheckRemoteIP setting
$Helper->ConfigSettingChange(
    Valid => 1,
    Key   => 'SessionCheckRemoteIP',
    Value => 0,
);

# create dynamic field object
my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

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

# create backed object
my $BackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
$Self->Is(
    ref $BackendObject,
    'Kernel::System::DynamicField::Backend',
    'Backend object was created successfully',
);


#create user for tests

my $TestUserLogin         = $Helper->TestUserCreate(
    Groups => [ 'admin', 'users', ],
);

my $UserID = $UserObject->UserLookup(
    UserLogin => $TestUserLogin,
);

push @Users, $UserID;

$Self->True(
    $UserID,
    'User Add ()',
);

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
                        CustomerUserUpdate => {
                                Type => 'Customer::CustomerUserUpdate',
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
                        CustomerUserUpdate => {
                                Type => 'Test::TestSimple',
                        },
                        SessionCreate => {
                                Type => 'Test::TestSimple',
                        },
                },
        },
};


my $WebserviceUpdate = $WebserviceObject->WebserviceUpdate(
        ID      => $WebserviceID,
        Name    => $WebserviceName,
        Config  => $WebserviceConfig,
        ValidID => 1,
        UserID  => $UserID,
);
$Helper->ConfigSettingChange(
	Key	=> 'CheckEmailAddress',
	Value	=> 0,
);


$Self->True(
        $WebserviceUpdate,
        "Updated web service $WebserviceID - $WebserviceName"
);

# create a customer user
#my $RandomID  = $Helper->GetRandomID();

my $Firstname = "Firstname$RandomID";
my $Lastname  = "Lastname$RandomID";
my $Login     = $RandomID;

my $CustomerUserID = $CustomerUserObject->CustomerUserAdd(
    Source         => 'CustomerUser',
    UserFirstname  => $Firstname,
    UserLastname   => $Lastname,
    UserCustomerID => "Customer$RandomID",
    UserLogin      => $Login,
    UserEmail      => "$Login\@example.com",
    ValidID        => 1,
    UserID         => 1,
);

$Self->True(
    $CustomerUserID,
    "CustomerUserID $CustomerUserID is created",
);

# set text field value
my $Result = $BackendObject->ValueSet(
    DynamicFieldConfig => \%DynamicFieldTextConfig,
    ObjectID           => $CustomerUserID,
    Value              => 'customer_user_field1',
    UserID             => 1,
);

# sanity check
$Self->True(
    $Result,
    "Text ValueSet() for Customer $CustomerUserID",
);


$Result = $BackendObject->ValueSet(
    DynamicFieldConfig => \%DynamicFieldDropdown,
    ObjectID           => $CustomerUserID,
    Value              => 'customer_user_field2',
    UserID             => 1,
);

# sanity check
$Self->True(
    $Result,
    "Dropdown ValueSet() for Customer $CustomerUserID",
);


$Result = $BackendObject->ValueSet(
    DynamicFieldConfig => \%DynamicFieldMultiselect,
    ObjectID           => $CustomerUserID,
    Value              => 'customer_user_field3',
    UserID             => 1,
);

# sanity check
$Self->True(
    $Result,
    "Dropdown ValueSet() for Customer $CustomerUserID",
);


$Result = $BackendObject->ValueSet(
    DynamicFieldConfig => \%DynamicFieldDate,
    ObjectID           => $CustomerUserID,
    Value              => '2016-09-18 00:00:00',
    UserID             => 1,
);

# sanity check
$Self->True(
    $Result,
    "Dropdown ValueSet() for Customer $CustomerUserID",
);


my %Customer = $CustomerUserObject->CustomerUserDataGet(
	User	=> $CustomerUserID,
	UserID	=> $UserID
);


# Get SessionID
# create requester object

my $RequesterSessionObject = $Kernel::OM->Get('Kernel::GenericInterface::Requester');

$Self->Is(
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


my $NewSessionID = $RequesterSessionResult->{Data}->{SessionID};

my @Tests = (

     {
        Name           => 'Missing customer user',
        SuccessRequest => '1',
        SuccessUpdate => '0',
        RequestData    => {},
        ExpectedReturnRemoteData => {
            Success => 1,
            Data    => {
		Error => {
			ErrorCode    => 'CustomerUserUpdate.MissingParameter',
			ErrorMessage => "CustomerUserUpdate: CustomerUserID parameter is missing!",
		}
            },
        },
	ExpectedReturnLocalData => {
            Success => 1,
	    ErrorMessage => 'CustomerUserUpdate.MissingParameter: CustomerUserUpdate: CustomerUserID parameter is missing!',
            Data    => {
		Error => {
			ErrorCode    => 'CustomerUserUpdate.MissingParameter',
                        ErrorMessage => "CustomerUserUpdate: CustomerUserID parameter is missing!",
			}
		},
        },
        Operation => 'CustomerUserUpdate',
    },

    {
        Name           => 'Empty request',
        SuccessRequest => '1',
        SuccessUpdate  => '0',
        RequestData    => {
		CustomerUserID	=> $CustomerUserID,
		CustomerUser	=> {}	
	},
        ExpectedReturnRemoteData => {
            Success => 1,
            Data    => {
		Error => {
			ErrorCode    => 'CustomerUserUpdate.EmptyRequest',
			ErrorMessage => "CustomerUserUpdate: The request data is invalid!",
		}
            },
        },
	ExpectedReturnLocalData => {
            Success => 1,
	    ErrorMessage   => 'CustomerUserUpdate.EmptyRequest: CustomerUserUpdate: The request data is invalid!',
            Data    => {
		Error => {
			ErrorCode    => 'CustomerUserUpdate.EmptyRequest',
                        ErrorMessage => "CustomerUserUpdate: The request data is invalid!",
			}
		},
        },
        Operation => 'CustomerUserUpdate',
    },

    {
        Name           => 'Update email',
        SuccessRequest => '1',
	SuccessUpdate  => 1,
        RequestData    => {
		CustomerUserID	=> $CustomerUserID,
		CustomerUser	=> {
			UserEmail => 'new-Email@example.com' 
		}	
	},
	Auth => {
		SessionID => $NewSessionID,
	},
        ExpectedReturnRemoteData => {
            Success => 1,
            Data    => {
		CustomerUserID	=> $CustomerUserID
            },
        },
	ExpectedReturnLocalData => {
            Success => 1,
            Data    => {
		CustomerUserID	=> $CustomerUserID
		},
        },
        Operation => 'CustomerUserUpdate',
    },

    {
        Name           => 'Update firstname',
        SuccessRequest => '1',
	SuccessUpdate  => 1,
        RequestData    => {
		CustomerUserID	=> $CustomerUserID,
		CustomerUser	=> {
			UserFirstname => 'Updated Firstname' 
		}	
	},
	Auth => {
		SessionID => $NewSessionID,
	},
        ExpectedReturnRemoteData => {
            Success => 1,
            Data    => {
		CustomerUserID	=> $CustomerUserID
            },
        },
	ExpectedReturnLocalData => {
            Success => 1,
            Data    => {
		CustomerUserID	=> $CustomerUserID
		},
        },
        Operation => 'CustomerUserUpdate',
    },

    {
        Name           => 'Update firstname and lastname',
        SuccessRequest => '1',
	SuccessUpdate  => 1,
        RequestData    => {
		CustomerUserID	=> $CustomerUserID,
		CustomerUser	=> {
			UserFirstname => 'Updated Firstname',
			UserLastname  => 'Updated Lastname' 
		}	
	},
	
        ExpectedReturnRemoteData => {
            Success => 1,
            Data    => {
		CustomerUserID	=> $CustomerUserID
            },
        },
	ExpectedReturnLocalData => {
            Success => 1,
            Data    => {
		CustomerUserID	=> $CustomerUserID
		},
        },
        Operation => 'CustomerUserUpdate',
    },

    {
        Name           => 'Update customer user id',
        SuccessRequest => '1',
	SuccessUpdate  => 1,
        RequestData    => {
		CustomerUserID	=> $CustomerUserID,
		CustomerUser	=> {
			UserCustomerID => 2,
		}	
	},
	
        ExpectedReturnRemoteData => {
            Success => 1,
            Data    => {
		CustomerUserID	=> $CustomerUserID
            },
        },
	ExpectedReturnLocalData => {
            Success => 1,
            Data    => {
		CustomerUserID	=> $CustomerUserID
		},
        },
        Operation => 'CustomerUserUpdate',
    },

    {
        Name           => 'Multiple update',
        SuccessRequest => '1',
	SuccessUpdate  => 1,
        RequestData    => {
		CustomerUserID	=> $CustomerUserID,
		CustomerUser	=> {
			UserCustomerID => 3,
			UserFirstname  => 'John',
			UserLastname   => 'Doe',
			UserEmail      => 'johndoe@example.com',
		}	
	},
	
        ExpectedReturnRemoteData => {
            Success => 1,
            Data    => {
		CustomerUserID	=> $CustomerUserID
            },
        },
	ExpectedReturnLocalData => {
            Success => 1,
            Data    => {
		CustomerUserID	=> $CustomerUserID
		},
        },
        Operation => 'CustomerUserUpdate',
    },

   {
        Name           => 'Update Text Dynamic field',
        SuccessRequest => '1',
	SuccessUpdate  => 1,
        RequestData    => {
		CustomerUserID	=> $CustomerUserID,
		CustomerUser	=> {
			UserFirstname	=> $Customer{UserFirstname}
		},
		DynamicField =>
			{
				Name	=> 'TestText' . $RandomID,
				Value	=> '2',
			},

	},
	
        ExpectedReturnRemoteData => {
            Success => 1,
            Data    => {
		CustomerUserID	=> $CustomerUserID
            },
        },
	ExpectedReturnLocalData => {
            Success => 1,
            Data    => {
		CustomerUserID	=> $CustomerUserID
		},
        },
        Operation => 'CustomerUserUpdate',
    }, 
    {
        Name           => 'Update Dropdown Dynamic field',
        SuccessRequest => '1',
	SuccessUpdate  => 1,
        RequestData    => {
		CustomerUserID	=> $CustomerUserID,
		CustomerUser	=> {
			UserFirstname	=> $Customer{UserFirstname}
		},
		DynamicField =>
			{
				Name	=> 'TestDropdown' . $RandomID,
				Value	=> '0',
			},

	},
	
        ExpectedReturnRemoteData => {
            Success => 1,
            Data    => {
		CustomerUserID	=> $CustomerUserID
            },
        },
	ExpectedReturnLocalData => {
            Success => 1,
            Data    => {
		CustomerUserID	=> $CustomerUserID
		},
        },
        Operation => 'CustomerUserUpdate',
    },
    {
        Name           => 'Update Multiselect and Date Dynamic field',
        SuccessRequest => '1',
	SuccessUpdate  => 1,
        RequestData    => {
		CustomerUserID	=> $CustomerUserID,
		CustomerUser	=> {
			UserFirstname	=> $Customer{UserFirstname}
		},
		DynamicField =>
		[
			{
				Name	=> 'TestMultiselect' . $RandomID,
				Value	=> [ 'a', ],
			},
			{
				Name	=> 'TestDate' . $RandomID,
				Value	=> '2023-09-30 00:00:00'
			},
		]
	},
        ExpectedReturnRemoteData => {
            Success => 1,
            Data    => {
		CustomerUserID	=> $CustomerUserID
            },
        },
	ExpectedReturnLocalData => {
            Success => 1,
            Data    => {
		CustomerUserID	=> $CustomerUserID
		},
        },
        Operation => 'CustomerUserUpdate',
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

	    # create local object

            my $LocalObject = "Kernel::GenericInterface::Operation::Customer::$Test->{Operation}"->new(
                DebuggerObject => $DebuggerObject,
                WebserviceID   => $WebserviceID,
            );

            $Self->Is(
                "Kernel::GenericInterface::Operation::Customer::$Test->{Operation}",
                ref $LocalObject,
                "$Test->{Name} - Create local object"
            );

    my %Auth = (
        UserLogin => $UserLogin,
        Password  => $Password,
    );
    
    if ($Test->{Auth} ) {
	  if ( IsHashRefWithData( $Test->{Auth} ) ) {
	     %Auth = %{ $Test->{Auth} };
	}
    }
    # start requester with our web service
    my $LocalResult = $LocalObject->Run(
        WebserviceID => $WebserviceID,
        Invoker      => $Test->{Operation},
        Data         => {
            %Auth,
    %{ $Test->{RequestData} },
        },
    );

    # check result
    $Self->Is(
        'HASH',
        ref $LocalResult,
        "$Test->{Name} - Local result structure is valid"
    );

    # create requester object
    my $RequesterObject = $Kernel::OM->Get('Kernel::GenericInterface::Requester');
    
    $Self->Is(
        'Kernel::GenericInterface::Requester',
        ref $RequesterObject,
        "$Test->{Name} - Create requester object"
    );

    # start requester with our web service
    my $RequesterResult = $RequesterObject->Run(
        WebserviceID => $WebserviceID,
        Invoker      => $Test->{Operation},
        Data         => {
		%Auth,
            %{ $Test->{RequestData} },
        },
    );


   # check result

    $Self->Is(
        'HASH',
        ref $RequesterResult,
        "$Test->{Name} - Requester result structure is valid"
    );

    $Self->Is(
        $RequesterResult->{Success},
	$Test->{SuccessRequest},
        "$Test->{Name} - Requester successful result"
    );

	$Self->True(
            $LocalResult,
            "$Test->{Name} - Local result CustomerUserID with True." 
        );

        # requester results

      
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

	if ($Test->{SuccessUpdate}) {

		my %UpdatedCustomer = $CustomerUserObject->CustomerUserDataGet(
			User	=> $Test->{RequestData}->{CustomerUserID},
			UserID	=> $UserID
		); 

		for my $Item ( keys %{$Test->{RequestData}->{CustomerUser} } ) {
		
			$Self->Is(
				$Test->{RequestData}->{CustomerUser}->{$Item},
				$UpdatedCustomer{$Item},
				"Updated $Item successfuly",
			);
		}

	}
		



}


my $WebserviceDelete = $WebserviceObject->WebserviceDelete(
        ID      =>      $WebserviceID,
        UserID  =>      $UserID,
);

$Self->True(
        $WebserviceDelete,
        "Deleted web service $WebserviceID",
);

my $CustomerUserDelete = $CustomerUserObject->CustomerUserDelete(
                CustomerUserID  => $CustomerUserID,
                UserID          => $UserID,
);

$Self->True(
                $CustomerUserDelete,
                "CustomerUserDelete() successful for CustomerUser ID $CustomerUserID",
);

my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

for my $User (@Users) {
	my $Success = $DBObject->Do(
	    SQL => "DELETE FROM user_preferences WHERE user_id = $User",
	);
	$Self->True(
	    $Success,
	    "User preference referenced to User ID $User is deleted!"
	);
	$Success = $DBObject->Do(
	    SQL => "delete from group_user where user_id = $User",
	);
	$Self->True(
	    $Success,
	    "Group user with $User is deleted!"
	);
	#
	$Success = $DBObject->Do(
	    SQL => "DELETE FROM users WHERE id = $User",
	);

	$Self->True(
	    $Success,
	    "User with ID $User is deleted!"
	);
}


DYNAMICFIELD:
for my $DynamicFieldID ( @DynamicFieldIDs ) {
	
	my $Success = $DBObject->Do(
	    SQL => "delete from dynamic_field_value WHERE field_id = $DynamicFieldID",
	);
	
	$Self->True(
		$Success,
		"Dynamic field value is deleted"
	);
   
	$Success = $DynamicFieldObject->DynamicFieldDelete(
		ID     => $DynamicFieldID,
		UserID => 1,
        );
	
	$Self->True(
		$Success,
		"Dynamic field with ID $DynamicFieldID is deleted",
	);	
}

$CacheObject->CleanUp();
 
1;
