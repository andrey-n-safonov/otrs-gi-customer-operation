# --
# Kernel/GenericInterface/Operation/Customer/CustomerCompanyUpdate.pm - GenericInterface CustomerCompany operation backend
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Operation::Customer::CustomerCompanyUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use parent qw(
  Kernel::GenericInterface::Operation::Common
  Kernel::GenericInterface::Operation::Customer::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::Customer::CustomerCompanyUpdate - GenericInterface CustomerCompanyUpdate Operation backend

=head1 PUBLIC INTERFACE

=head2 new()

usually, you want to create an instance of this
by using Kernel::GenericInterface::Operation->new();

=cut


sub new {
	my ( $Type, %Param ) = @_;

	my $Self = {};
	bless( $Self, $Type );

	# check needed objects
	for my $Needed (qw( DebuggerObject WebserviceID )) {
		if ( !$Param{$Needed} ) {
			return {
				Success      => 0,
				ErrorMessage => "Got no $Needed!",
			};
		}
		$Self->{$Needed} = $Param{$Needed};
	}

	return $Self;
}

=head2 Run()

perform CustomerCompanyUpdate Operation. This will return the updated CustomerID.

    my $Result = $OperationObject->Run(
        Data => {
            UserLogin => 'Agent1',          # UserLogin or SessionID is
                                            #   required
            SessionID => '123',
            Password  => 'some password',   # if UserLogin or customerUserLogin is sent then
                                            #   Password is required
            CustomerID     => 'example.com',                                    # current CustomerID is required
            CustomerCompany => {
				CustomerCompanyID       => 'anotherexample.com',                # new CustomerID
				CustomerCompanyName     => 'New Customer Inc.',
				CustomerCompanyStreet   => '5201 Blue Lagoon Drive',
				CustomerCompanyZIP      => '33126',
				CustomerCompanyLocation => 'Miami',
				CustomerCompanyCountry  => 'USA',
				CustomerCompanyURL      => 'http://example.com',
				CustomerCompanyComment  => 'some comment',
            },
            DynamicField => [                                                  # optional
                {
                    Name   => FieldNameX,
                    Value  => 'some data',                                          # value type depends on the dynamic field
                },
                # ...
            ],
            # or
            # DynamicField {
            #    Name   => FieldNameX,
            #    Value  => 'some data',
            #},
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        ErrorMessage    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            CustomerID    => 'anotherexample.com',  # CustomerID in OTRS (help desk system)
            Error => {                              # should not return errors
                    ErrorCode    => 'CustomerCompanyUpdate.ErrorCode'
                    ErrorMessage => 'Error Description'
            },
        },
    };

=cut


sub Run {
	my ( $Self, %Param ) = @_;
	
	my $Result = $Self->Init(WebserviceID => $Self->{WebserviceID},);

	if ( !$Result->{Success} ) {
		$Self->ReturnError(
			ErrorCode    => 'Webservice.InvalidConfiguration',
			ErrorMessage => $Result->{ErrorMessage},
		);
	}

	# check needed stuff
	my ( $UserID, $UserType ) = $Self->Auth(%Param,);

	return $Self->ReturnError(
		ErrorCode    => 'CustomerCompanyUpdate.AuthFail',
		ErrorMessage => "CustomerCompanyUpdate: Authorization failing!",
	) if !$UserID;

	# if ( !IsHashRefWithData($Param{Data}->{CustomerCompany} && !IsHashRefWithData( $Param{Data}->{DynamicField} )) ) {
		# return $Self->ReturnError(
			# ErrorCode    => 'CustomerCompanyUpdate.EmptyRequest',
			# ErrorMessage => "CustomerCompanyUpdate: The request data is invalid!",
		# );
	# }

	# check needed stuff
	for my $Needed (qw(CustomerID)) {
		if ( !$Param{Data}->{$Needed} ) {
			return $Self->ReturnError(
				ErrorCode    => 'CustomerCompanyUpdate.MissingParameter',
				ErrorMessage => "CustomerCompanyUpdate: $Needed parameter is missing!",
			);
		}
	}
    my $CustomerID = $Param{Data}->{CustomerID};
	
	my $Success = $Self->ValidateCustomerCompany(
		CustomerID =>  $CustomerID,
	);
    if ( !$Success){
		return $Self->ReturnError(
			ErrorCode    => 'CustomerCompanyUpdate.NotValid',
			ErrorMessage => "CustomerCompanyUpdate: CustomerID does not exist!",
		);
	}

	# isolate CustomerCompany parameter
	my $CustomerCompany = $Param{Data}->{CustomerCompany};

	# remove leading and trailing spaces
	if ( $CustomerCompany ) {
		for my $Attribute ( sort keys %{$CustomerCompany} ) {
			if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' && $CustomerCompany->{$Attribute} ) {

				#remove leading spaces
				$CustomerCompany->{$Attribute} =~ s{\A\s+}{};

				#remove trailing spaces
				$CustomerCompany->{$Attribute} =~ s{\s+\z}{};
			}
		}
	}
	my $DynamicField;
	my @DynamicFieldList;
	my $DynamicFieldObjectID;
	if ( defined $Param{Data}->{DynamicField} ) {

		# isolate DynamicField parameter
		$DynamicField = $Param{Data}->{DynamicField};

		# homogenate input to array
		if ( ref $DynamicField eq 'HASH' ) {
			push @DynamicFieldList, $DynamicField;
		}else {
			@DynamicFieldList = @{$DynamicField};
		}

		# check DynamicField internal structure
		for my $DynamicFieldItem (@DynamicFieldList) {
			if ( !IsHashRefWithData($DynamicFieldItem) ) {
				return {
					ErrorCode => 'CustomerCompanyUpdate.InvalidParameter',
					ErrorMessage =>"CustomerCompanyUpdate: CustomerCompany->DynamicField parameter is invalid!",
				};
			}

			# remove leading and trailing spaces
			for my $Attribute ( sort keys %{$DynamicFieldItem} ) {
				if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

					#remove leading spaces
					$DynamicFieldItem->{$Attribute} =~ s{\A\s+}{};

					#remove trailing spaces
					$DynamicFieldItem->{$Attribute} =~ s{\s+\z}{};
				}
			}

			# check DynamicField attribute values
			my $DynamicFieldCheck = $Self->_CheckDynamicField(
				DynamicField => $DynamicFieldItem,
				ObjectType	=> 'CustomerCompany',
			);

			if ( !$DynamicFieldCheck->{Success} ) {
				return $Self->ReturnError( %{$DynamicFieldCheck} );
			}
		}
		# get ObjectID by CustomerID
		my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
		my $ObjectMapping = $DynamicFieldObject->ObjectMappingGet( 
			ObjectName => $CustomerID,
			ObjectType => 'CustomerCompany',
		);

		if (!IsHashRefWithData($ObjectMapping)) {
			$DynamicFieldObjectID = $DynamicFieldObject->ObjectMappingCreate(
				ObjectName => $CustomerID,
				ObjectType => 'CustomerCompany',
			);
		}else{
			$DynamicFieldObjectID = $ObjectMapping->{$CustomerID};
		}

		if ( !$DynamicFieldObjectID ){
			return $Self->ReturnError(
				ErrorCode => 'CustomerCompanyUpdate.DynamicFieldSetError',
				ErrorMessage =>"CustomerCompanyUpdate: can't get ObjectID by name",
			);
		}
	}

	return $Self->_CustomerCompanyUpdate(
		CustomerID       => $CustomerID,
		CustomerCompany  => $CustomerCompany,
		DynamicFieldList => \@DynamicFieldList,
		ObjectID         => $DynamicFieldObjectID,
		UserID           => $UserID,
	);
}

=begin Internal:


=head2 _CustomerCompanyUpdate()

updates a CustomerCompany and sets dynamic fields if specified.

    my $Response = $OperationObject->_CustomerCompanyUpdate(
        CustomerID      => 'example.com'
        CustomerCompany => $CustomerCompany,         # all CustomerCompany parameters
        DynamicField    => $DynamicField,            # all dynamic field parameters
        UserID          => 123,
    );

    returns:

    $Response = {
        Success => 1,                               # if everything is OK
        Data => {
            CustomerID     => 'example.com',        # or value of NewCustomerID if specified in CustomerCompany data
        }
    }

    $Response = {
        Success      => 0,                         # if unexpected error
        ErrorMessage => "$Param{ErrorCode}: $Param{ErrorMessage}",
    }

=cut


sub _CustomerCompanyUpdate {
	my ( $Self, %Param ) = @_;

	my $CustomerID = $Param{CustomerID};
	my $CustomerCompany  = $Param{CustomerCompany};
	my $DynamicFieldList = $Param{DynamicFieldList};
	my $ObjectID = $Param{ObjectID};
	my $UserID = $Param{UserID};

	# get CustomeCompany object
	my $CustomerCompanyObject = $Kernel::OM->Get('Kernel::System::CustomerCompany');

	# get current CustomerCompany data
	my %CustomerCompanyEntry = $CustomerCompanyObject->CustomerCompanyGet(
		CustomerID => $CustomerID,
		UserID         => $UserID,
	);

	# prepare new CustomerCompany data
	my %newCustomerCompanyData;
	$newCustomerCompanyData{UserID} = $UserID;
	for my $Item ( keys %{$CustomerCompany} ) {
		if ( $CustomerCompany->{$Item} && 
		(!$CustomerCompanyEntry{$Item} || $CustomerCompany->{$Item} ne "$CustomerCompanyEntry{$Item}" )){
			$newCustomerCompanyData{$Item} = $CustomerCompany->{$Item};
		}
	}
	
	if (defined $newCustomerCompanyData{CustomerCompanyID}) {
		$newCustomerCompanyData{CustomerID} = $newCustomerCompanyData{CustomerCompanyID};
		$newCustomerCompanyData{CustomerCompanyID} = $CustomerID;
	}	
	else {
		$newCustomerCompanyData{CustomerID} = $CustomerID;
	}

	# set required by Kernel::System::CustomerCompany::CustomerCompanyUpdate
	$newCustomerCompanyData{CustomerCompanyName} = $newCustomerCompanyData{CustomerCompanyName} || $CustomerCompanyEntry{CustomerCompanyName};
	
	# TODO make disable/enable
	$newCustomerCompanyData{ValidID} = 1;
	# update CustomerCompany parameters
	my $Success = $CustomerCompanyObject->CustomerCompanyUpdate(
		%newCustomerCompanyData,
		UserID         => $UserID,
	);
	if ( !$Success ) {
		return {
			Success => 0,
			Errormessage =>'CustomerCompany could not be updated, please contact system administrator!',
		};
	}else {
		$CustomerID = $newCustomerCompanyData{CustomerID};
	}

	# set dynamic fields
	for my $DynamicField ( @{$DynamicFieldList} ) {
		my $Result = $Self->SetDynamicFieldValue(
			%{$DynamicField},
			ObjectID  => $ObjectID,
			UserID    => $UserID,
		);

		if ( !$Result->{Success} ) {
			my $ErrorMessage =$Result->{ErrorMessage} || "Dynamic Field $DynamicField->{Name} could not be set,". " please contact the system administrator";

			return {
				Success      => 0,
				ErrorMessage => $ErrorMessage,
			};
		}
	}

	return {
		Success => 1,
		Data    => {
			CustomerID     => $CustomerID,
		},
	};


}

1;

=end Internal:

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<https://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
