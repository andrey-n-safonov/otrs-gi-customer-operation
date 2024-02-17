# --
# Kernel/GenericInterface/Operation/Customer/CustomerCompanyGet.pm - GenericInterface CustomerCompany operation backend
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::GenericInterface::Operation::Customer::CustomerCompanyGet;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use parent qw(
  Kernel::GenericInterface::Operation::Common
  Kernel::GenericInterface::Operation::Customer::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::Customer::CustomerCompanyGet - GenericInterface CustomerCompany operation backend

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
            UserLogin => 'Agent1',          # UserLogin or SessionID is
                                            #   required
            SessionID => '123',
            Password  => 'some password',   # if UserLogin or customerUserLogin is sent then
                                            # Password is required
            CustomerID     => 'example.com',# CustomerID is required
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        ErrorMessage => '',                               # In case of an error
        Data => {
		    CustomerCompany	=> [
		        {
		            UserFax	=> "",
		            UserLogin"=> "SomeName",
					....
		        },
				.....
		    ]
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
		ErrorCode    => 'CustomerCompanyGet.AuthFail',
		ErrorMessage => "CustomerCompany: Authorization failing!",
	) if !$UserID;

	# check needed stuff
	for my $Needed (qw(CustomerID)) {
		if ( !$Param{Data}->{$Needed} ) {
			return $Self->ReturnError(
				ErrorCode    => 'CustomerCompanyGet.MissingParameter',
				ErrorMessage => "CustomerCompanyGet: $Needed parameter is missing!",
			);
		}
	}

	my $ErrorMessage = '';

	# all needed variables
	my @CustomerIDs;
	if ( IsStringWithData( $Param{Data}->{CustomerID} ) ) {
		@CustomerIDs = split( /,/, $Param{Data}->{CustomerID} );
	}elsif ( IsArrayRefWithData( $Param{Data}->{CustomerID} ) ) {
		@CustomerIDs = @{ $Param{Data}->{CustomerID} };
	}else {
		return $Self->ReturnError(
			ErrorCode    => 'CustomerCompanyGet.WrongStructure',
			ErrorMessage => "CustomerCompanyGet: Structure for CustomerID is not correct!",
		);
	}

	my $ReturnData = {Success => 1,};
	my @Item;

	# start CustomerCompany loop
	for my $CustomerID (@CustomerIDs) {

		my $CustomerCompanyObject = $Kernel::OM->Get('Kernel::System::CustomerCompany');

		# get the CustomerCompany entry
		my %CustomerCompanyEntry = $CustomerCompanyObject->CustomerCompanyGet(
			CustomerID => $CustomerID,
			UserID         => $UserID,
		);

		if ( !IsHashRefWithData( \%CustomerCompanyEntry ) ) {

			$ErrorMessage = 'Could not get CustomerCompany data'. ' in Kernel::GenericInterface::Operation::Customer::CustomerCompanyGet::Run()';

			return $Self->ReturnError(
				ErrorCode    => 'CustomerCompanyGet.NotValidCustomerID',
				ErrorMessage => "CustomerCompanyGet: $ErrorMessage",
			);
		}
		my $CustomerCompanyBundle = {%CustomerCompanyEntry,};

		push @Item, $CustomerCompanyBundle;
	}

	if ( !scalar @Item ) {
		$ErrorMessage = 'Could not get CustomerCompany data'. ' in Kernel::GenericInterface::Operation::Customer::CustomerCompanyGet::Run()';

		return $Self->ReturnError(
			ErrorCode    => 'CustomerCompanyGet.NotCustomerCompanyData',
			ErrorMessage => "CustomerCompanyGet: $ErrorMessage",
		);

	}

	# set customer user data into return structure
	$ReturnData->{Data}->{CustomerCompany} = \@Item;

	# return result
	return $ReturnData;
}

1;

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
