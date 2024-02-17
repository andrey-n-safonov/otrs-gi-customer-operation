# --
# Kernel/GenericInterface/Operation/Customer/Common.pm - GenericInterface Customer common operation backend
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Operation::Customer::Common;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsHashRefWithData IsStringWithData);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::Ticket::Common - Base class for all Ticket Operations

=head1 PUBLIC INTERFACE

=head2 Init()

Initialize the operation by checking the web service configuration and gather of the dynamic fields.

    my $Return = $CommonObject->Init(
        WebserviceID => 1,
    );

Returns:

    $Return = {
        Success => 1,                       # or 0 in case of failure,
        ErrorMessage => 'Error Message',
    }

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    if ( !$Param{WebserviceID} ) {
        return {
            Success      => 0,
            ErrorMessage => "Got no WebserviceID!",
        };
    }

    # get web service configuration
    my $Webservice = $Kernel::OM->Get('Kernel::System::GenericInterface::Webservice')->WebserviceGet(
        ID => $Param{WebserviceID},
    );

    if ( !IsHashRefWithData($Webservice) ) {
        return {
            Success => 0,
            ErrorMessage =>
                'Could not determine Web service configuration'
                . ' in Kernel::GenericInterface::Operation::CustomerUser::Common::new()',
        };
    }

	# get the dynamic fields
	my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
		Valid      => 1,
		ObjectType => [ 'CustomerCompany', 'CustomerUser' ],
	);

	# create a Dynamic Fields lookup table (by name)
    DYNAMICFIELD:
	for my $DynamicField ( @{$DynamicField} ) {
		next DYNAMICFIELD if !$DynamicField;
		next DYNAMICFIELD if !IsHashRefWithData($DynamicField);
		next DYNAMICFIELD if !$DynamicField->{Name};
		$Self->{DynamicFieldLookup}->{ $DynamicField->{Name} } = $DynamicField;
	}

    return {
        Success => 1,
    };
}

=head2 ValidateCustomerCompany()

Checks if the given customer user or customer ID is valid.

    my $Success = $CommonObject->ValidateCustomer(
        CustomerUser   => 'some type',
    );

Returns:

    my $Success = 1;            # or 0

=cut

sub ValidateCustomerCompany {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{CustomerID} || !length $Param{CustomerID};

    # check for customer company
    my $CustomerCompanyData = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet(
        CustomerID => $Param{CustomerID},
    );

    return if !IsHashRefWithData($CustomerCompanyData);

    return 1;
}

=head2 ValidateDynamicFieldName()

Checks if the given dynamic field name is valid.

    my $Success = $CommonObject->ValidateDynamicFieldName(
        Name => 'some name',
    );

Returns:

    my $Success = 1;            # or 0

=cut

sub ValidateDynamicFieldName {
    my ( $Self, %Param ) = @_;

    return if !IsHashRefWithData( $Self->{DynamicFieldLookup} );
    return if !$Param{Name};

    return if !$Self->{DynamicFieldLookup}->{ $Param{Name} };
    return if !IsHashRefWithData( $Self->{DynamicFieldLookup}->{ $Param{Name} } );

    return 1;
}

=cut

=head2 ValidateDynamicFieldValue()

Checks if the given dynamic field value is valid.

    my $Success = $CommonObject->ValidateDynamicFieldValue(
        Name  => 'some name',
        Value => 'some value',          # String or Integer or DateTime format
    );

    my $Success = $CommonObject->ValidateDynamicFieldValue(
        Value => [                      # Only for fields that can handle multiple values like
            'some value',               #   Multiselect
            'some other value',
        ],
    );

    returns
    $Success = 1                        # or 0

=cut

sub ValidateDynamicFieldValue {
    my ( $Self, %Param ) = @_;

    return if !IsHashRefWithData( $Self->{DynamicFieldLookup} );

    # possible structures are string and array, no data inside is needed
    if ( !IsStringWithData( $Param{Value} ) && ref $Param{Value} ne 'ARRAY' ) {
        return;
    }

    # get dynamic field config
    my $DynamicFieldConfig = $Self->{DynamicFieldLookup}->{ $Param{Name} };

    # Validate value.
    my $ValidateValue = $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->FieldValueValidate(
        DynamicFieldConfig => $DynamicFieldConfig,
        Value              => $Param{Value},
        UserID             => 1,
    );

    return $ValidateValue;
}

=head2 ValidateDynamicFieldObjectType()

Checks if the given dynamic field name is valid.

    my $Success = $CommonObject->ValidateDynamicFieldObjectType(
        Name    => 'some name',
    );

Returns:

    my $Success = 1;            # or 0

=cut

sub ValidateDynamicFieldObjectType {
    my ( $Self, %Param ) = @_;

    return if !IsHashRefWithData( $Self->{DynamicFieldLookup} );
    return if !$Param{Name};

    return if !$Self->{DynamicFieldLookup}->{ $Param{Name} };
    return if !IsHashRefWithData( $Self->{DynamicFieldLookup}->{ $Param{Name} } );

    my $DynamicFieldConfg = $Self->{DynamicFieldLookup}->{ $Param{Name} };
    return if $DynamicFieldConfg->{ObjectType} ne $Param{ObjectType};

    return 1;
}

=head2 SetDynamicFieldValue()

Sets the value of a dynamic field.
based on Kernel::GenericInterface::Operation::Ticket::Common 

    my $Result = $CommonObject->SetDynamicFieldValue(
        Name      => 'some name',           # the name of the dynamic field
        Value     => 'some value',          # String or Integer or DateTime format
        ObjectID  => 123,
        UserID    => 123,
    );

Returns:

    my $Result = {
        Success => 1,                        # if everything is ok
    }

    my $Result = {
        Success      => 0,
        ErrorMessage => 'Error description'
    }

=cut

sub SetDynamicFieldValue {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Name UserID)) {
        if ( !IsStringWithData( $Param{$Needed} ) ) {
			return {
				ErrorCode => 'CustomerController.SetDynamicFieldValue',
				ErrorMessage => "SetDynamicFieldValue() Invalid value for $Needed, just string is allowed!",
			};
        }
    }

    # check value structure
    if ( !IsStringWithData( $Param{Value} ) && ref $Param{Value} ne 'ARRAY' ) {
        return {
			ErrorCode => 'CustomerController.SetDynamicFieldValue',
			ErrorMessage => "SetDynamicFieldValue() Invalid value for Value, just string and array are allowed!"
        };
    }

    return if !IsHashRefWithData( $Self->{DynamicFieldLookup} );

    # get dynamic field config
    my $DynamicFieldConfig = $Self->{DynamicFieldLookup}->{ $Param{Name} };

    my $Success = $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DynamicFieldConfig,
        ObjectID           => $Param{ObjectID},
        Value              => $Param{Value},
        UserID             => $Param{UserID},
    );

    return {
        Success => $Success,
    };
}


=head2 _CheckDynamicField()

checks if the given dynamic field parameter is valid.

    my $DynamicFieldCheck = $OperationObject->_CheckDynamicField(
        DynamicField => $DynamicField,              # all dynamic field parameters
    );

    returns:

    $DynamicFieldCheck = {
        Success => 1,                               # if everything is OK
    }

    $DynamicFieldCheck = {
        ErrorCode    => 'Function.Error',           # if error
        ErrorMessage => 'Error description',
    }

=cut

sub _CheckDynamicField {
	my ( $Self, %Param ) = @_;

	my $DynamicField = $Param{DynamicField};
    $DynamicField->{ObjectType} = $Param{ObjectType};

	# check DynamicField item internally
	for my $Needed (qw(Name Value)) {
		if (!defined $DynamicField->{$Needed}
			|| ( !IsStringWithData( $DynamicField->{$Needed} ) && ref $DynamicField->{$Needed} ne 'ARRAY' )){
			return {
				ErrorCode    => 'CustomerController.MissingParameter',
				ErrorMessage => "CustomerController: DynamicField->$Needed parameter is missing!",
			};
		}
	}

	# check DynamicField->Name
	if ( !$Self->ValidateDynamicFieldName( %{$DynamicField} ) ) {
		return {
			ErrorCode    => 'CustomerController.InvalidParameter',
			ErrorMessage => "CustomerController: DynamicField->Name parameter is invalid!",
		};
	}

	# check objectType for dynamic field
	if (!$Self->ValidateDynamicFieldObjectType(%{$DynamicField})){
		return {
			ErrorCode => 'CustomerController.IncorrectObjectType',
			ErrorMessage =>"CustomerController: Incorrect ObjectType for DynamicFieldObject",
		};
	}

	# check DynamicField->Value
	if ( !$Self->ValidateDynamicFieldValue( %{$DynamicField} ) ) {
		return {
			ErrorCode    => 'CustomerController.InvalidParameter',
			ErrorMessage => "CustomerController: DynamicField->Value parameter is invalid!",
		};
	}

	# if everything is OK then return Success
	return {Success => 1,};
}

1;

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<https://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
