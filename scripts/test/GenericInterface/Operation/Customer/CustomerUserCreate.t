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
use Kernel::GenericInterface::Operation::Customer::CustomerUserCreate;
my $CustomerUserObject  = $Kernel::OM->Get('Kernel::System::CustomerUser');
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
my $CacheObject	 = $Kernel::OM->Get('Kernel::System::Cache');
my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

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

# enable customer groups support
$Helper->ConfigSettingChange(
    Valid => 1,
    Key   => 'CustomerGroupSupport',
    Value => 1,
);

my @DFIDs;
my %DynamicFieldTextConfig = (
    Name       => "Unittest1$RandomID",
    FieldOrder => 9991,
    FieldType  => 'Text',
    ObjectType => 'CustomerUser',
    Label      => 'Description',
    ValidID    => 1,
    Config     => {
        DefaultValue => '',
    },
);
my $FieldTextID = $DynamicFieldObject->DynamicFieldAdd(
    %DynamicFieldTextConfig,
    UserID  => 1,
    Reorder => 0,
);
$Self->True(
    $FieldTextID,
    "Dynamic Field $FieldTextID"
);

# add ID
$DynamicFieldTextConfig{ID} = $FieldTextID;
push @DFIDs, $FieldTextID;

# add dropdown dynamic field
my %DynamicFieldDropdownConfig = (
    Name       => "Unittest2$RandomID",
    FieldOrder => 9992,
    FieldType  => 'Dropdown',
    ObjectType => 'CustomerUser',
    Label      => 'Description',
    ValidID    => 1,
    Config     => {
        PossibleValues => {
            1 => 'One',
            2 => 'Two',
            3 => 'Three',
            0 => '0',
        },
    },
);
my $FieldDropdownID = $DynamicFieldObject->DynamicFieldAdd(
    %DynamicFieldDropdownConfig,
    UserID  => 1,
    Reorder => 0,
);
$Self->True(
    $FieldDropdownID,
    "Dynamic Field $FieldDropdownID"
);

# add ID
$DynamicFieldDropdownConfig{ID} = $FieldDropdownID;
push @DFIDs, $FieldDropdownID;

# add multiselect dynamic field
my %DynamicFieldMultiselectConfig = (
    Name       => "Unittest3$RandomID",
    FieldOrder => 9993,
    FieldType  => 'Multiselect',
    ObjectType => 'CustomerUser',
    Label      => 'Multiselect label',
    ValidID    => 1,
    Config     => {
        PossibleValues => {
            1 => 'Value9ßüß',
            2 => 'DifferentValue',
            3 => '1234567',
        },
    },
);
my $FieldMultiselectID = $DynamicFieldObject->DynamicFieldAdd(
    %DynamicFieldMultiselectConfig,
    UserID  => 1,
    Reorder => 0,
);
$Self->True(
    $FieldMultiselectID,
    "Dynamic Field $FieldMultiselectID"
);

# add ID
$DynamicFieldMultiselectConfig{ID} = $FieldMultiselectID;
push @DFIDs, $FieldMultiselectID;

my %DynamicFieldDateTimeConfig = (
    Name       => "DateField",
    FieldOrder => 9994,
    FieldType  => 'DateTime',
    ObjectType => 'CustomerUser',
    Label      => 'Description',
    Config     => {
        DefaultValue  => 0,
        YearsInFuture => 0,
        YearsInPast   => 0,
        YearsPeriod   => 0,
    },
    ValidID => 1,
);
my $FieldDateTimeID = $DynamicFieldObject->DynamicFieldAdd(
    %DynamicFieldDateTimeConfig,
    UserID  => 1,
    Reorder => 0,
);
$Self->True(
    $FieldDateTimeID,
    "Dynamic Field $FieldDateTimeID"
);
$DynamicFieldDateTimeConfig{ID} = $FieldDateTimeID;
push @DFIDs, $FieldDateTimeID;

#create user for tests

my $TestUserLogin         = $Helper->TestUserCreate(
    Groups => [ 'admin', 'users', ],
);

my $UserID = $UserObject->UserLookup(
    UserLogin => $TestUserLogin,
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
                        CustomerUserCreate => {
                                Type => 'Customer::CustomerUserCreate',
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
                        CustomerUserCreate => {
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

my $TestCustomerUserDelete = sub {
	my %Param = @_;

	my @CustomerUserIDs = @{ $Param{CustomerUserIDs} };

	sleep 1;

	CUSTOMERUSERID:
	for my $CustomerUserID (@CustomerUserIDs) {
	
		next CUSTOMERUSERID if !$CustomerUserID;
		my $CustomerUserDelete = $CustomerUserObject->CustomerUserDelete(
			CustomerUserID	=> $CustomerUserID,
			UserID		=> 1,
		);

		if ( !$CustomerUserDelete ) {
			sleep 3;
			$CustomerUserDelete = $CustomerUserObject->CustomerUserDelete(
					CustomerUserID	=> $CustomerUserID,
					UserID		=> 1,
			);
		}
		$Self->True(
			$CustomerUserDelete,
			"Delete cutomer user - $CustomerUserID"
		);
		# sanity check
		$Self->True(
			$CustomerUserDelete,
			"CustomerUserDelete() successful for CustomerUser ID $CustomerUserID"
		);
	}
	return 1;
};

# start requester with our web service
my $RequesterSessionResult = $RequesterSessionObject->Run(
    WebserviceID => $WebserviceID,
    Invoker      => 'SessionCreate',
    Data         => {
        UserLogin => $UserLogin,
        Password  => $Password,
    },
);

my $NewSessionID = $RequesterSessionResult->{Data}->{SessionID};

my $Key = 'Special';

my $CustomerEmail = 'unittest' . 1 . $Helper->GetRandomID() .  '-root@localhost.com';

my %Errors = (
	EmailInUse => {
	   Data => {
		Error => {
			ErrorCode    => 'CustomerUserCreate.EmailInUse',
			ErrorMessage => "CustomerUserCreate: Email address already in use for another customer user!",
			
			}
		},
	   Success => 1,
	}
	

);
my @Tests = 
(
    {
        Name           => 'Empty Request',
        SuccessRequest => 1,
        SuccessCreate  => 0,
        RequestData    => {},
        ExpectedData   => {
            Data => {
                Error => {
                    ErrorCode	 => 'CustomerUserCreate.MissingParameter',
		    ErrorMessage => "CustomerUserCreate: CustomerUser  parameter is missing or not valid!",
                },
            },
            Success => 1
        },
        Operation => 'CustomerUserCreate',
    }, 

    {
        Name           => 'Invalid CustomerUser',
        SuccessRequest => 1,
        SuccessCreate  => 0,
        RequestData    => {
		CustomerUser => 1,
	},
        ExpectedData   => {
            Data => {
                Error => {
                    ErrorCode	 => 'CustomerUserCreate.MissingParameter',
		    ErrorMessage => "CustomerUserCreate: CustomerUser  parameter is missing or not valid!",
                },
            },
            Success => 1
        },
        Operation => 'CustomerUserCreate',
    },

    {
        Name           => 'Invalid DynamicField',
        SuccessRequest => 1,
        SuccessCreate  => 0,
        RequestData    => {
		CustomerUser => {
			Test => 1,
		},
		DynamicField => 1,
	},
        ExpectedData   => {
            Data => {
                Error => {
                    ErrorCode	 => 'CustomerUserCreate.MissingParameter',
		    ErrorMessage => "CustomerUserCreate: CustomerUser  parameter is missing or not valid!",
                },
            },
            Success => 1
        },
        Operation => 'CustomerUserCreate',
    },

    {
        Name           => 'Missing lastname',
        SuccessRequest => 1,
        SuccessCreate  => 0,
        RequestData    => {
		CustomerUser => {
			UserLogin => 'ValidLogin',
		},
	},
        ExpectedData   => {
            Data => {
                Error => {
                    ErrorCode    => 'CustomerUserCreate.MissingParameter',
                    ErrorMessage => "CustomerUserCreate: UserLastname parameter is missing!",

		},
            },
            Success => 1
        },
        Operation => 'CustomerUserCreate',
    },

   {
        Name           => 'Missing email',
        SuccessRequest => 1,
        SuccessCreate  => 0,
        RequestData    => {
		CustomerUser => {
			UserLogin => 'ValidLogin',
			UserLastname => 'ValidLastname',
		},
	},
        ExpectedData   => {
            Data => {
                Error => {
                    ErrorCode    => 'CustomerUserCreate.MissingParameter',
                    ErrorMessage => "CustomerUserCreate: UserEmail parameter is missing!",

		},
            },
            Success => 1
        },
        Operation => 'CustomerUserCreate',
    },

    {
        Name           => 'Missing Firstname',
        SuccessRequest => 1,
        SuccessCreate  => 0,
        RequestData    => {
		CustomerUser => {
			UserLogin => 'ValidLogin',
			UserLastname => 'ValidLastname',
			UserEmail    => 'validemail-Email@example.com',
		},
	},
        ExpectedData   => {
            Data => {
                Error => {
                    ErrorCode    => 'CustomerUserCreate.MissingParameter',
                    ErrorMessage => "CustomerUserCreate: UserFirstname parameter is missing!",

		},
            },
            Success => 1
        },
        Operation => 'CustomerUserCreate',
    },

   {
        Name           => 'Bad source',
        SuccessRequest => 1,
        SuccessCreate  => 0,
        RequestData    => {
		CustomerUser => {
			Source		=> 'NotCustomerUser',	  
			UserLogin	=> 'ValidLogin',
			UserLastname	=> 'ValidLastname',
			UserEmail	=> 'validemail-Email@example.com',
			UserFirstname	=> 'ValidFirstname',
		},
	},
        ExpectedData   => {
            Data => {
                Error => {
                    ErrorCode    => 'CustomerUserCreate.ValidateSource',
                    ErrorMessage => "CustomerUserCreate: Source is invalid!",
		},
            },
            Success => 1
        },
        Operation => 'CustomerUserCreate',
    },
 
 
    {
        Name           => 'Invalid email',
        SuccessRequest => 1,
        SuccessCreate  => 0,
        RequestData    => {
		CustomerUser => {
			UserLogin	=> 'ValidLogin',
			UserLastname	=> 'ValidLastname',
			UserEmail	=> 'Invalid' . '-Email@example.com',
			UserFirstname	=> 'ValidFirstname',
		},
	},
        ExpectedData   => {
            Data => {
                Error => {
                    ErrorCode    => 'CustomerUserCreate.EmailValidate',
                    ErrorMessage => "CustomerUserCreate: Email address not valid!",
		},
            },
            Success => 1
        },
        Operation => 'CustomerUserCreate',
    },

    #{
    #    Name           => 'Email in use',
#	Type	       => 'EmailCustomerUser',
 #       SuccessRequest => 1,
  #      SuccessCreate  => 0,
   #     RequestData    => {
#		CustomerUser => {
#			UserLogin	=> 'ValidLogin',
#			UserLastname	=> 'ValidLastname',
#			UserEmail	=> $Key . '-Email@example.com',
#			UserFirstname	=> 'ValidFirstname',
#		},
#	},
 #       ExpectedData   => {
  #          Data => {
   #             Error => {
    #                ErrorCode    => 'CustomerUserUpdate.EmailInUse',
     #               ErrorMessage => "CustomerUserUpdate: Email address already in use for another customer user!",
#		},
 #           },
  #          Success => 1
   #     },
    #    Operation => 'CustomerUserCreate',
    #},

    {
        Name           => 'CustomerUser valid',
        SuccessRequest => 1,
        SuccessCreate  => 1,
        RequestData    => {
		CustomerUser => {
			Source		=> 'CustomerUser',
			UserLastname	=> 'Doe',
			UserEmail	=> $CustomerEmail,
			UserFirstname	=> 'John',
			UserLogin	=> 'validlogin',
			Password	=> 'some-pass',
			ValidID		=> 1,
		},
	},    
        Operation => 'CustomerUserCreate',
	ExpectedData => {
		Data => {
			CustomerUserID => 'validlogin',
		},
		Success => 1,
	}
     },

     {
        Name           => 'DF text',
        SuccessRequest => 1,
        SuccessCreate  => 1,
        RequestData    => {
		CustomerUser => {
			Source		=> 'CustomerUser',
			UserLastname	=> 'Doe',
			UserEmail	=> 'df-text' . $CustomerEmail,
			UserFirstname	=> 'John',
			UserLogin	=> 'validlogintext',
			Password	=> 'some-pass',
			ValidID		=> 1,
		},
		DynamicFields => {
			Name  => $DynamicFieldTextConfig{Name},
			Value => 'customer_user1',
		},
	},    
        Operation => 'CustomerUserCreate',
	ExpectedData => {
		Data => {
			CustomerUserID => 'validlogintext',
		},
		Success => 1,
	}
     },
     {
        Name           => 'DF multiselect',
        SuccessRequest => 1,
        SuccessCreate  => 1,
        RequestData    => {
		CustomerUser => {
			Source		=> 'CustomerUser',
			UserLastname	=> 'Doe',
			UserEmail	=> 'df-multi' . $CustomerEmail,
			UserFirstname	=> 'John',
			UserLogin	=> 'validlogin-multi',
			Password	=> 'some-pass',
			ValidID		=> 1,
		},
		DynamicFields => {
			Name  => $DynamicFieldMultiselectConfig{Name},
			Value => 'customer_user1',
		},
	},    
        Operation => 'CustomerUserCreate',
	ExpectedData => {
		Data => {
			CustomerUserID => 'validlogin-multi',
		},
		Success => 1,
	}
     },
     {
        Name           => 'DF drop+data',
        SuccessRequest => 1,
        SuccessCreate  => 1,
        RequestData    => {
		CustomerUser => {
			Source		=> 'CustomerUser',
			UserLastname	=> 'Doe',
			UserEmail	=> 'df-ddrop' . $CustomerEmail,
			UserFirstname	=> 'John',
			UserLogin	=> 'validlogin-ddrop',
			Password	=> 'some-pass',
			ValidID		=> 1,
		},
		DynamicFields => [ 
			{
				Name  => $DynamicFieldDropdownConfig{Name},
				Value => 'customer_user1',
			},
			{
				Name  => $DynamicFieldDateTimeConfig{Name},
				Value => '2023-11-25 12:28:00',
			},
		]
	},    
        Operation => 'CustomerUserCreate',
	ExpectedData => {
		Data => {
			CustomerUserID => 'validlogin-ddrop',
		},
		Success => 1,
	}
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
TEST:
for my $Test (@Tests) {
            if ( $Test->{Type} eq 'EmailCustomerUser' ) {
                $Helper->ConfigSettingChange(
                    Valid => 1,
                    Key   => 'CheckEmailAddresses',
                    Value => 0,
                );
            }
            else {
                $Helper->ConfigSettingChange(
                    Valid => 1,
                    Key   => 'CheckEmailAddresses',
                    Value => 1,
                );
            }	   
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


    # create requester object
    my $RequesterObject = $Kernel::OM->Get('Kernel::GenericInterface::Requester');

    $Self->Is(
        'Kernel::GenericInterface::Requester',
        ref $RequesterObject,
        "$Test->{Name} - Create requester object"
    );


    if ( $Test->{SuccessCreate} ) {
    my ($Remote, $Local) = () x 2;
    my @loops = (0..1);
    foreach(@loops) {
	    if ($_ == 0) {
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

			# local results
		        $Self->True(
		            $LocalResult->{Data}->{CustomerUserID},
		            "$Test->{Name} - Local result CustomerUserID with True."
		        );
	
			$Local = $LocalResult;

			$Self->IsDeeply(
		            $LocalResult->{Data}->{Error},
		            undef,
		            "$Test->{Name} - Local result Error is undefined."
		        );

		        $Self->IsDeeply(
		            $LocalResult,
		            $Test->{ExpectedData},
		            "$Test->{Name} - Local result matched with expected local call result.",
		        );
			
#			$Self->IsDeeply(
#				$RequesterResult,
#				$Errors{EmailInUse},
#				"detected error",
#			);		
			
			my @CustomerUserIDs = ( $LocalResult->{Data}->{CustomerUserID} );
			$TestCustomerUserDelete->(
					CustomerUserIDs => \@CustomerUserIDs,
			);
		    } else {
			    # start requester with our web service
			    my $RequesterResult = $RequesterObject->Run(
			        WebserviceID => $WebserviceID,
			        Invoker      => $Test->{Operation},
			        Data         => {
			            %Auth,
			            %{ $Test->{RequestData} },
			        },
			    );

			    $Self->Is(
			        $RequesterResult->{Success},
			        $Test->{SuccessRequest},
			        "$Test->{Name} - Requester successful result"
			    );
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
			   # check result
			   
			    $Self->Is(
			        'HASH',
			        ref $RequesterResult,
			        "$Test->{Name} - Requester result structure is valid"
			    );
			# requester results
		        
			$Self->IsDeeply(
		                $RequesterResult,
		                $Test->{ExpectedData},
		                "$Test->{Name} - Requester success status (needs configured and running webserver)"
		        );

			$Remote = $RequesterResult;
		
			# append a string to local return(specific)
			$Errors{EmailInUse}->{ErrorMessage} = 'CustomerUserCreate.EmailInUse: CustomerUserCreate: Email address already in use for another customer user!';

			$Self->IsDeeply(
				$LocalResult,
				$Errors{EmailInUse},
				"detected error",
			);
			$Self->Is(
				$RequesterResult->{Data}->{Error},
				undef,
				"$Test->{Name} - Remote result Error is undefined.",
			);

			my @CustomerUserIDs = ( $RequesterResult->{Data}->{CustomerUserID} );
			$TestCustomerUserDelete->(
					CustomerUserIDs => \@CustomerUserIDs,
			);
			
			}
		}

	        # consistency check

                $Self->IsDeeply(
                    $Local,
                    $Remote,
                    "$Test->{Name} - Local result matched with remote result.",
                );

    }

    # tests supposed to fail
    else {

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

		    # start requester with our web service
		    my $RequesterResult = $RequesterObject->Run(
		        WebserviceID => $WebserviceID,
		        Invoker      => $Test->{Operation},
		        Data         => {
		            %Auth,
		            %{ $Test->{RequestData} },
		        },
		    );

		    $Self->Is(
		        $RequesterResult->{Success},
		        $Test->{SuccessRequest},
		        "$Test->{Name} - Requester successful result"
		    );
		    
		   # check result
		   
		    $Self->Is(
		        'HASH',
		        ref $RequesterResult,
		        "$Test->{Name} - Requester result structure is valid"
		    );
	
        $Self->Is(
            $LocalResult->{Data}->{Error}->{ErrorCode},
            $Test->{ExpectedData}->{Data}->{Error}->{ErrorCode},
            "$Test->{Name} - Local result ErrorCode matched with expected local call result."
        );
        $Self->True(
            $LocalResult->{Data}->{Error}->{ErrorMessage},
            "$Test->{Name} - Local result ErrorMessage with true."
        );
        $Self->IsNot(
            $LocalResult->{Data}->{Error}->{ErrorMessage},
            '',
            "$Test->{Name} - Local result ErrorMessage is not empty."
        );

        $Self->Is(
            $LocalResult->{ErrorMessage},
            $LocalResult->{Data}->{Error}->{ErrorCode}
                . ': '
                . $LocalResult->{Data}->{Error}->{ErrorMessage},
            "$Test->{Name} - Local result ErrorMessage (outside Data hash) matched with concatenation"
                . " of ErrorCode and ErrorMessage within Data hash."
        );

        # remove ErrorMessage parameter from direct call
        # result to be consistent with SOAP call result
        if ( $LocalResult->{ErrorMessage} ) {
            delete $LocalResult->{ErrorMessage};
        }
       
	# sanity check
        $Self->False(
            $LocalResult->{ErrorMessage},
            "$Test->{Name} - Local result ErrorMessage (outside Data hash) got removed to compare"
                . " local and remote tests."
        );

        $Self->IsDeeply(
            $LocalResult,
            $RequesterResult,
            "$Test->{Name} - Local result matched with remote result."
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
 

# delete user
my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
 

for my $ID (@DFIDs) {
        my $Success = $DBObject->Do(
                SQL => "delete from dynamic_field where id = $ID",
        );
          
        $Self->True(
            $Success,
            "Dynamic field with id $ID is deleted!"
	);
}

foreach (@Users) {
	my $Success = $DBObject->Do(
	    SQL => "DELETE FROM user_preferences WHERE user_id = $_",
	);

	$Self->True(
	    $Success,
	    "User preference referenced to User ID $_ is deleted!"
	);

	$Success = $DBObject->Do(
	   SQL => "delete from group_user where user_id = $_",
	);

	$Self->True(
	    $Success,
	    "Group user referenced to User ID $_ is deleted!"
	);

	$Success = $DBObject->Do(
	    SQL => "DELETE FROM users WHERE id = $_",
	);
	
	$Self->True(
	    $Success,
	    "User with ID $_ is deleted!"
	);
}


$CacheObject->CleanUp();
	
1;
