# --
# Kernel/GenericInterface/Operation/Customer/CustomerCompanySearch.pm - GenericInterface CustomerCompany operation backend
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Operation::Customer::CustomerCompanySearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use parent qw(
  Kernel::GenericInterface::Operation::Common
  Kernel::GenericInterface::Operation::Customer::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::Customer::CustomerCompanySearch - GenericInterface Customer Search Operation backend

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
	for my $Needed (qw(DebuggerObject WebserviceID)) {
		if ( !$Param{$Needed} ) {
			return {
				Success      => 0,
				ErrorMessage => "Got no $Needed!",
			};
		}

		$Self->{$Needed} = $Param{$Needed};
	}

	# get config for this screen
	$Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('GenericInterface::Operation::CustomerCompanySearch');

	return $Self;
}

=head2 Run()

perform CustomerCompanySearch Operation. This will return a CustomerCompany ID list.

    my $Result = $OperationObject->Run(
        Data => {
            UserLogin => 'Agent1',          # UserLogin or SessionID is
                                            #   required
            SessionID => '123',
            Password  => 'some password',   # if UserLogin or customerUserLogin is sent then
                                            #   Password is required
            SearchDetail => {
                CustomerID          => 'example*',                                  # (optional)
                CustomerCompanyName => 'Name*',                                     # (optional)

                # array parameters are used with logical OR operator (all values are possible which
                are defined in the config selection hash for the field)
                CustomerCompanyCountry => [ 'Austria', 'Germany', ],                # (optional)

                # DynamicFields
                #   At least one operator must be specified. Operators will be connected with AND,
                #       values in an operator with OR.
                #   You can also pass more than one argument to an operator: ['value1', 'value2']
                DynamicField_FieldNameX => {
                    Equals            => 123,
                    Like              => 'value*',                # "equals" operator with wildcard support
                    GreaterThan       => '2001-01-01 01:01:01',
                    GreaterThanEquals => '2001-01-01 01:01:01',
                    SmallerThan       => '2002-02-02 02:02:02',
                    SmallerThanEquals => '2002-02-02 02:02:02',
                }

                SortBy => [ 'CustomerID', 'CustomerCompanyCountry' ],              # (optional)
                # ignored if the result type is 'COUNT'
                # default: [ 'CustomerID' ]

                # Additional information for OrderBy:
                # The OrderByDirection can be specified for each OrderBy attribute.
                # The pairing is made by the array indices.

                OrderBy => [ 'Down', 'Up' ],                               # (optional)
                # ignored if the result type is 'COUNT'
                # (Down | Up) Default: [ 'Down' ]

                Result => 'ARRAY' || 'COUNT',                                       # (optional)
                # default: ARRAY, returns an array of change ids
                # COUNT returns a scalar with the number of found changes

                Limit => 50,                                                       # (optional)
                # ignored if the result type is 'COUNT'
            },
        },
    );


    $Result = {
        Success      => 1,                                # 0 or 1
        ErrorMessage => '',                               # In case of an error
        Data         => {
            CustomerIDs => [ 1, 2, 3, 4 ],                # if Result is ARRAY or absent
            CustomerIDs => 10,                            # # if Result is COUNT
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

	my ( $UserID, $UserType ) = $Self->Auth(%Param,);

	return $Self->ReturnError(
		ErrorCode    => 'CustomerCompanySearch.AuthFail',
		ErrorMessage => "CustomerCompanySearch: Authorization failing!",
	) if !$UserID;

	# perform search
    my $CustomerIDs = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanySearchDetail(
            %{ $Param{Data}->{SearchDetail} },
	);

	if ($CustomerIDs) {
		return {
			Success => 1,
			Data    => {
				CustomerIDs => $CustomerIDs,
			},
		};
	}

	# return result
	return {
		Success => 1,
		Data    => {
            CustomerIDs => 0,
        },
	};
}

1;

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<https://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut