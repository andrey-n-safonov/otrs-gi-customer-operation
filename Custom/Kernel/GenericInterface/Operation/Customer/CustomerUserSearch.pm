# --
# Kernel/GenericInterface/Operation/Customer/CustomerUserSearch.pm - GenericInterface CustomerUser operation backend
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::GenericInterface::Operation::Customer::CustomerUserSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use parent qw(
  Kernel::GenericInterface::Operation::Common
  Kernel::GenericInterface::Operation::Customer::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::Customer::CustomerUserSearch - GenericInterface Customer Search Operation backend

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
	$Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('GenericInterface::Operation::CustomerUserSearch');

	return $Self;
}

=head2 Run()

perform CustomerUserSearch Operation. This will return a CustomerUser ID list.

    my $Result = $OperationObject->Run(
        Data => {
            UserLogin => 'Agent1',
            Password  => 'some password',   # plain text password
            SearchDetail => {

                # all search fields possible which are defined in CustomerUser::EnhancedSearchFields
                UserLogin     => 'example*',                                    # (optional)
                UserFirstname => 'Firstn*',                                     # (optional)

                # special parameters
                CustomerCompanySearchCustomerIDs => [ 'example.com' ],          # (optional)
                ExcludeUserLogins                => [ 'example', 'doejohn' ],   # (optional)

                # array parameters are used with logical OR operator (all values are possible which
                are defined in the config selection hash for the field)
                UserCountry              => [ 'Austria', 'Germany', ],          # (optional)

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

                OrderBy => [ 'UserLogin', 'UserCustomerID' ],                   # (optional)
                # ignored if the result type is 'COUNT'
                # default: [ 'UserLogin' ]
                # (all search fields possible which are defined in
                CustomerUser::EnhancedSearchFields)

                # Additional information for OrderBy:
                # The OrderByDirection can be specified for each OrderBy attribute.
                # The pairing is made by the array indices.

                OrderByDirection => [ 'Down', 'Up' ],                          # (optional)
                # ignored if the result type is 'COUNT'
                # (Down | Up) Default: [ 'Down' ]

                Result => 'ARRAY' || 'COUNT',                                  # (optional)
                # default: ARRAY, returns an array of change ids
                # COUNT returns a scalar with the number of found changes

                Limit => 100,                                                  # (optional)
                # ignored if the result type is 'COUNT'
            },
        },
    );


    $Result = {
        Success      => 1,                                # 0 or 1
        ErrorMessage => '',                               # In case of an error
        Data         => {
            CustomerUserIDs => [ 1, 2, 3, 4 ],
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
		ErrorCode    => 'CustomerUserSearch.AuthFail',
		ErrorMessage => "CustomerUserSearch: Authorization failing!",
	) if !$UserID;

	my $SearchDetail = $Param{Data}->{SearchDetail};

	# get parameter from data
	my %GetParam = $Self->_GetParams( %{ $Param{Data}->{SearchDetail} } );

	# get dynamic fields
	my %DynamicFieldSearchParameters = $Self->_GetDynamicFields( %{ $Param{Data}->{SearchDetail} } );

	# perform search

	my @CustomerUserIDs = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSearchDetail(%GetParam,%DynamicFieldSearchParameters,);


	if (@CustomerUserIDs) {

		return {
			Success => 1,
			Data    => {
				CustomerUserIDs => \@CustomerUserIDs,
			},
		};
	}

	# return result
	return {
		Success => 1,
		Data    => {},
	};
}

=begin Internal:

=head2 _GetParams()

get search parameters.

    my %GetParam = _GetParams(
        %Params,                          # all ticket parameters
    );

    returns:

    %GetParam = {
        AllowedParams => 'WithContent', # return not empty parameters for search
    }

=cut


sub _GetParams {
	my ( $Self, %Param ) = @_;

	# get single params
	my %GetParam;

	my %SearchableFields = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserSearchFields();

	for my $Item (sort keys %SearchableFields,qw(Limit Result)){

		# get search string params (get submitted params)
		if ( IsStringWithData( $Param{$Item} ) ) {

			$GetParam{$Item} = $Param{$Item};

			# remove white space on the start and end
			$GetParam{$Item} =~ s/\s+$//g;
			$GetParam{$Item} =~ s/^\s+//g;
		}
	}

	# get array params
	for my $Item (qw(OrderBy OrderByDirection)){

		# get search array params
		my @Values;
		if ( IsArrayRefWithData( $Param{$Item} ) ) {
			@Values = @{ $Param{$Item} };
		}elsif ( IsStringWithData( $Param{$Item} ) ) {
			@Values = ( $Param{$Item} );
		}
		$GetParam{$Item} = \@Values if scalar @Values;
	}

	return %GetParam;

}


=head2 _GetDynamicFields()

get search parameters.

    my %DynamicFieldSearchParameters = _GetDynamicFields(
        %Params,                          # all ticket parameters
    );

    returns:

    %DynamicFieldSearchParameters = {
        'AllAllowedDF' => 'WithData',   # return not empty parameters for search
    }

=cut


sub _GetDynamicFields {
	my ( $Self, %Param ) = @_;

	# dynamic fields search parameters for ticket search
	my %DynamicFieldSearchParameters;

	# get single params
	my %AttributeLookup;

	# get the dynamic fields for ticket object
	$Self->{DynamicField} = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
		Valid      => 1,
		ObjectType => ['CustomerUser'],
	);

	my %DynamicFieldsRaw;
	if ( $Param{DynamicField} ) {
		my %SearchParams;
		if ( IsHashRefWithData( $Param{DynamicField} ) ) {
			$DynamicFieldsRaw{ $Param{DynamicField}->{Name} } = $Param{DynamicField};
		}elsif ( IsArrayRefWithData( $Param{DynamicField} ) ) {
			%DynamicFieldsRaw = map { $_->{Name} => $_ } @{ $Param{DynamicField} };
		}else {
			return %DynamicFieldSearchParameters;
		}

	}else {

		# Compatibility with older versions of the web service.
		for my $ParameterName ( sort keys %Param ) {
			if ( $ParameterName =~ m{\A DynamicField_ ( [a-zA-Z\d]+ ) \z}xms ) {
				$DynamicFieldsRaw{$1} = $Param{$ParameterName};
			}
		}
	}

	# loop over the dynamic fields configured
  DYNAMICFIELD:
	for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
		next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
		next DYNAMICFIELD if !$DynamicFieldConfig->{Name};

		# skip all fields that does not match with current field name
		next DYNAMICFIELD if !$DynamicFieldsRaw{ $DynamicFieldConfig->{Name} };

		next DYNAMICFIELD if !IsHashRefWithData( $DynamicFieldsRaw{ $DynamicFieldConfig->{Name} } );

		my %SearchOperators = %{ $DynamicFieldsRaw{ $DynamicFieldConfig->{Name} } };

		delete $SearchOperators{Name};

		# set search parameter
		$DynamicFieldSearchParameters{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = \%SearchOperators;
	}

	# allow free fields

	return %DynamicFieldSearchParameters;

}


=end Internal:

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<https://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut

1;
