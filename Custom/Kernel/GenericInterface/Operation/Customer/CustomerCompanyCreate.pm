# --
# Kernel/GenericInterface/Operation/Customer/CustomerCompanyCreate.pm - GenericInterface CustomerCompany operation backend
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::GenericInterface::Operation::Customer::CustomerCompanyCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
  Kernel::GenericInterface::Operation::Common
  Kernel::GenericInterface::Operation::Customer::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::Customer::CustomerCompanyCreate - GenericInterface CustomerCompany operation backend

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
	for my $Needed (qw(DebuggerObject WebserviceID)){
		if ( !$Param{$Needed} ) {

			return {
				Success      => 0,
				ErrorMessage => "Got no $Needed!"
			};
		}

		$Self->{$Needed} = $Param{$Needed};
	}

	return $Self;
}

=head2 Run()

Retrieve a customer user info by id value.

    my $Result = $OperationObject->Run(
        Data => {
            UserLogin => 'Agent1',            # authorizing by login/password
            Password  => 'some password',     # plain text password
			SessionID => 'valid session id',  # or provide valid SessionID
            CustomerCompany => {
                CustomerID              => 'test',
                CustomerCompanyName     => 'test company',
                CustomerCompanyStreet   => '--',
                CustomerCompanyZIP      => '--',
                CustomerCompanyCity     => '--',
                CustomerCompanyCountry  => 'Russia',
                CustomerCompanyURL      => '--',
                CustomerCompanyComment  => 'testing',
            },
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        ErrorMessage => '',                               # In case of an error
        Data => {
            ID  => 'test2'
        },
    };

=cut


sub Run {
	my ( $Self, %Param ) = @_;
	my $Result = $Self->Init(WebserviceID => $Self->{WebserviceID},);

	if ( !$Result->{Success} ) {
		return $Self->ReturnError(
			ErrorCode    => 'Webservice.InvalidConfiguration',
			ErrorMessage => $Result->{ErrorMessage},
		);
	}

	my ( $UserID, $UserType ) = $Self->Auth(%Param,);

	return $Self->ReturnError(
		ErrorCode    => 'CustomerCompanyCreate.AuthFail',
		ErrorMessage => "CustomerCompany: Authorization failing!",
	) if !$UserID;

	# check needed hashes
	for my $Needed (qw(CustomerID CustomerCompanyName)) {
		if ( !$Param{Data}->{CustomerCompany}->{$Needed} ) {
			return $Self->ReturnError(
				ErrorCode    => 'CustomerCompanyCreate.MissingParameter',
				ErrorMessage => "CustomerCompanyCreate: $Needed  parameter is missing or not valid!",
			);
		}
	}

	# isolate CustomerCompany parameter
	my $CustomerCompany = $Param{Data}->{CustomerCompany};
	
    # remove leading and trailing spaces
	for my $Attribute ( sort keys %{$CustomerCompany} ) {
		if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

			#remove leading spaces
			$CustomerCompany->{$Attribute} =~ s{\A\s+}{};

			#remove trailing spaces
			$CustomerCompany->{$Attribute} =~ s{\s+\z}{};
		}
	}

	for my $Needed (qw(CustomerID CustomerCompanyName)) {
		if ( !$CustomerCompany->{$Needed} ) {
			return $Self->ReturnError(
				ErrorCode    => 'CustomerCompanyCreate.MissingParameter',
				ErrorMessage => "CustomerCompanyCreate: CustomerCompany->$Needed parameter is missing!",
			);
		}
	}
	
    if ( defined $Self->ValidateCustomerCompany( $CustomerCompany->{CustomerID} ) ) {
		return $Self->ReturnError(
			ErrorCode    => 'CustomerCompanyCreate.Exist',
			ErrorMessage =>"CustomerCompanyCreate: This CustomerID already exist!",
		);
	}

    my $CustomerCompanyObject = $Kernel::OM->Get('Kernel::System::CustomerCompany');

	# Check CustomerCompanyName must be unique
	my $Exist = $CustomerCompanyObject->CustomerCompanySearchDetail(
		CustomerCompanyName     => $CustomerCompany->{CustomerCompanyName},
	);
	
	if ( !IsHashRefWithData($Exist) ) {
		return $Self->ReturnError(
			ErrorCode => 'CustomerCompanyCreate.Exist',
			ErrorMessage =>"CustomerCompanyCreate: $CustomerCompany->{CustomerCompanyName} already exist!",
		);
	}
	my $ID = $CustomerCompanyObject->CustomerCompanyAdd(
		CustomerID              => $CustomerCompany->{CustomerID},
		CustomerCompanyName     => $CustomerCompany->{CustomerCompanyName},
		CustomerCompanyStreet   => $CustomerCompany->{CustomerCompanyStreet} || '',
		CustomerCompanyZIP      => $CustomerCompany->{CustomerCompanyZIP} || '',
		CustomerCompanyCity     => $CustomerCompany->{CustomerCompanyCity} || '',
		CustomerCompanyCountry  => $CustomerCompany->{CustomerCompanyCountry} || '',
		CustomerCompanyURL      => $CustomerCompany->{CustomerCompanyURL} || '',
		CustomerCompanyComment  => $CustomerCompany->{CustomerCompanyComment} || '',
		ValidID                 => 1,
		UserID                  => $UserID,
	);

	if ( !$ID ) {
		return $Self->ReturnError(
			ErrorCode    => 'CustomerCompanyCreate.Unknown',
			ErrorMessage => 'CustomerCompany could not be created, please contact the system administrator',
		);
	}

	# return result
	return {
		Success => 1,
		Data => {
			ID => $ID,
		},
	}
}

1;

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
