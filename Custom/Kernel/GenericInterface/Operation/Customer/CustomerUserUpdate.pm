# --
# Kernel/GenericInterface/Operation/Customer/CustomerUserUpdate.pm - GenericInterface CustomerCompany operation backend
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Operation::Customer::CustomerUserUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use parent qw(
  Kernel::GenericInterface::Operation::Common
  Kernel::GenericInterface::Operation::Customer::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::Customer::CustomerUserUpdate - GenericInterface CustomerCompanyUpdate Operation backend

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

perform CustomerUserUpdate Operation. This will return the CustomerUserID if not error rised.

    my $Result = $OperationObject->Run(
        Data => {
            UserLogin         => 'some agent login',     # UserLogin is required
            Password  => 'some passwor                   # Password is required
            CustomerUserID     => 'mh',                  # current user login is required
            CustomerUser => {
                UserLogin      => 'mhuber',               # new user login. Uses CustomerUserID if not specified
                UserCustomerID => 'test',                 # CustomerCompanyID
                UserFirstname  => 'Huber',
                UserLastname   => 'Manfred',
                UserEmail      => 'email@example.com',
                # other appropriated params check in current CustomerUser Map 
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
        Success         => 1,                            # 0 or 1
        ErrorMessage    => '',                           # in case of error
        Data            => {                             # result data payload after Operation
            CustomerUserID    => 'mhuber',               # CustomerUserID in OTRS (help desk system)
            Error => {                                   # should not return errors
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

	#check needed stuff
	my ( $UserID, $UserType ) = $Self->Auth(%Param,);
	
	my $CustomerUserID = $Param{Data}->{CustomerUserID};

	return $Self->ReturnError(
		ErrorCode    => 'CustomerUserUpdate.AuthFail',
		ErrorMessage => "CustomerUser: Authorization failing!",
	) if !$UserID;

	for my $Needed (qw(CustomerUserID )) {
		if ( !$Param{Data}->{$Needed} ) {
			return $Self->ReturnError(
				ErrorCode    => 'CustomerUserUpdate.MissingParameter',
				ErrorMessage => "CustomerUserUpdate: $Needed parameter is missing!",
			);
		}
	}

	if ( !IsHashRefWithData( $Param{Data}->{CustomerUser} ) ) {
		return $Self->ReturnError(
			ErrorCode    => 'CustomerUserUpdate.EmptyRequest',
			ErrorMessage => "CustomerUserUpdate: The request data is invalid!",
		);
	}
	
	my $DynamicField;
	my @DynamicFieldList;
	my $DynamicFieldObjectID;
	if ( defined$Param{Data}->{DynamicField} ){

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
				return $Self->ReturnError (
					ErrorCode => 'CustomerController.InvalidParameter',
					ErrorMessage =>"CustomerController: CustomerUser->DynamicField parameter is invalid!",
				);
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
				ObjectType	=> 'CustomerUser'
			);
			if ( !$DynamicFieldCheck->{Success} ) {
				return $Self->ReturnError( %{$DynamicFieldCheck} );
			}
		}

		# get ObjectID by UserLogin
		my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
		my $ObjectMapping = $DynamicFieldObject->ObjectMappingGet( 
			ObjectName => $CustomerUserID,
			ObjectType => 'CustomerUser',
		);


		if (!IsHashRefWithData($ObjectMapping)) {
			$DynamicFieldObjectID = $DynamicFieldObject->ObjectMappingCreate(
				ObjectName => $CustomerUserID,
				ObjectType => 'CustomerUser',
			);
		}else{
			$DynamicFieldObjectID = $ObjectMapping->{$CustomerUserID};
		}

		if ( !$DynamicFieldObjectID ){
			return $Self->ReturnError(
				ErrorCode => 'CustomerUserUpdate.DynamicFieldSetError',
				ErrorMessage =>"CustomerUserUpdate: can't get ObjectID by Object Name",
			);
		}
	}	

	return $Self->_CustomerUserUpdate(
		CustomerUserID   => $CustomerUserID,
		CustomerUser     => $Param{CustomerUser},
		DynamicFieldList => \@DynamicFieldList,
		ObjectID         => $DynamicFieldObjectID,
		UserID           => $UserID,
	);
}

=begin Internal:


=head2 _CustomerUserUpdate()

updates a CustomerUser and sets dynamic fields if specified.

    my $Response = $OperationObject->_CustomerUserUpdate(
        CustomerUserID      => 'someuserlogin'
        CustomerCompany => $CustomerCompany,         # all CustomerUser parameters
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

sub _CustomerUserUpdate {
	my ( $Self, %Param ) = @_;

	my $CustomerUserID = $Param{CustomerUserID};
	my $CustomerUser  = $Param{CustomerUser};
	my $DynamicFieldList = $Param{DynamicFieldList};
	my $ObjectID = $Param{ObjectID};
	my $UserID = $Param{UserID};

	my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
	my %oldCustomerUserData = $CustomerUserObject->CustomerUserDataGet( 
		User => $CustomerUserID, 
	);

	# prepare new CustomerUser data
	my %newCustomerUserData;

	for my $Item (keys %{$CustomerUser}) {
		$newCustomerUserData{$Item} = $CustomerUser->{$Item};
	}

	# set required by Kernel::System::CustomerUser::CustomerUserUpdate
	$newCustomerUserData{UserID} = $UserID;
	$newCustomerUserData{ID} = $CustomerUserID;
	$newCustomerUserData{UserLogin} = $newCustomerUserData{UserLogin} || $newCustomerUserData{ID};
	$newCustomerUserData{UserFirstname} = $newCustomerUserData{UserFirstname} || $oldCustomerUserData{UserFirstname};
	$newCustomerUserData{UserLastname} = $newCustomerUserData{UserLastname} || $oldCustomerUserData{UserLastname};
	$newCustomerUserData{UserCustomerID} = $newCustomerUserData{UserCustomerID} || $oldCustomerUserData{UserCustomerID};

	# TODO make disable/enable
	$newCustomerUserData{ValidID} = 1;

	if ( $newCustomerUserData{UserEmail} ){
		my $CheckItemObject = $Kernel::OM->Get('Kernel::System::CheckItem');
		if (!$CheckItemObject->CheckEmail( Address => $newCustomerUserData{UserEmail} )){
			return $Self->ReturnError(
				ErrorCode    => 'CustomerUserUpdate.EmailValidate',
				ErrorMessage => "CustomerUserUpdate: Email address ($newCustomerUserData{UserEmail}) not valid (". $CheckItemObject->CheckError() . ")!",
			);
		}
	}else{
		$newCustomerUserData{UserEmail} = $oldCustomerUserData{UserEmail};
	}
	if ( $newCustomerUserData{UserCustomerID} ) {
		if (!$Self->ValidateCustomerCompany(CustomerID => $newCustomerUserData{UserCustomerID} ) ){
			return $Self->ReturnError(
				ErrorCode    => 'CustomerUserUpdate.Update',
				ErrorMessage => "CustomerUserUpdate: CustomerID $newCustomerUserData{UserCustomerID} does not exist!",
			);
		}
	}

	my $Success = $CustomerUserObject->CustomerUserUpdate(
		%newCustomerUserData,
	);
	if ( !$Success ) {
		return $Self->ReturnError(
			ErrorCode    => 'CustomerUserUpdate.Update',
			ErrorMessage => "CustomerUserUpdate: CustomerUser could not be updated, please contact system administrator!",
		);
	}

	# set up Dynamic Fields
	for my $DynamicField ( @{$DynamicFieldList} ) {
		my $Result = $Self->SetDynamicFieldValue(
			%{$DynamicField},
			ObjectID  	=> $ObjectID,
			UserID		=> $UserID,
		);
		if ( !$Result->{Success} ) {
			my $ErrorMessage =$Result->{ErrorMessage} || "Dynamic Field $DynamicField->{Name} could not be set,". " please contact the system administrator";
			return $Self->ReturnError(
				ErrorCode => 'CustomerUserUpdate.DynamicFieldSetError',
				ErrorMessage =>"CustomerUserUpdate: $ErrorMessage",
			);
		}
	}

	return {
		Success => 1,
		Data    => {
			CustomerUserID     => $CustomerUserID,
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
