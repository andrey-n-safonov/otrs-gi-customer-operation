# --
# Kernel/GenericInterface/Operation/CustomerUser/CustomerUserGet.pm - GenericInterface CustomerUser operation backend
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::GenericInterface::Operation::Customer::CustomerUserGet;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use parent qw(
  Kernel::GenericInterface::Operation::Common
  Kernel::GenericInterface::Operation::Customer::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::Customer::CustomerUserGet - GenericInterface CustomerUser operation backend

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
                                            #   Password is required
            CustomerUserID  => 'some user login', # current CustomerUserID (UserLogin by default)
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        ErrorMessage => '',                               # In case of an error
        Data => {
		    CustomerUser	=> [
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

	my $Result = $Self->Init(
		WebserviceID => $Self->{WebserviceID},
	);

	if ( !$Result->{Success} ) {
		return $Self->ReturnError(
			ErrorCode    => 'Webservice.InvalidConfiguration',
			ErrorMessage => $Result->{ErrorMessage},
		);
	}

	my ( $UserID, $UserType ) = $Self->Auth(
		%Param,
	);

	return $Self->ReturnError(
		ErrorCode    => 'CustomerUserGet.AuthFail',
		ErrorMessage => "CustomerUser: Authorization failing!",
	) if !$UserID;

	# check needed stuff
	for my $Needed (qw(CustomerUserID)) {
		if ( !$Param{Data}->{$Needed} ) {
			return $Self->ReturnError(
				ErrorCode    => 'CustomerUserGet.MissingParameter',
				ErrorMessage => "CustomerUserGet: $Needed parameter is missing!",
			);
		}
	}
	
	my $ErrorMessage = '';

	# all needed variables
	my @CustomerUserIDs;
	if ( IsStringWithData( $Param{Data}->{CustomerUserID} ) ) {
		@CustomerUserIDs = split( /,/, $Param{Data}->{CustomerUserID} );
	}elsif ( IsArrayRefWithData( $Param{Data}->{CustomerUserID} ) ) {
		@CustomerUserIDs = @{ $Param{Data}->{CustomerUserID} };
	}else {
		return $Self->ReturnError(
			ErrorCode    => 'CustomerUserGet.WrongStructure',
			ErrorMessage => "CustomerUserGet: Structure for CustomerUserID is not correct!",
		);
	}

    my $ReturnData = {
        Success => 1,
    };
    my @Item;

    # start customeruser loop
    for my $CustomerUserID (@CustomerUserIDs) {

        my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

        # get the CustomerUser entry
        my %CustomerUserEntry = $CustomerUserObject->CustomerUserDataGet(
            User => $CustomerUserID,
            UserID         => $UserID,
        );

        if ( !IsHashRefWithData( \%CustomerUserEntry ) ) {

            $ErrorMessage = 'Could not get CustomerUser data'
                . ' in Kernel::GenericInterface::Operation::Customer::CustomerUserGet::Run()';

            return $Self->ReturnError(
                ErrorCode    => 'CustomerUserGet.NotValidCustomerUserID',
                ErrorMessage => "CustomerUserGet: $ErrorMessage",
            );
        }
        my $CustomerUserBundle = {
            %CustomerUserEntry,
        };

		push @Item, $CustomerUserBundle;
	}

	if ( !scalar @Item ) {
		$ErrorMessage = 'Could not get CustomerUser data'
			. ' in Kernel::GenericInterface::Operation::Customer::CustomerUserGet::Run()';

		return $Self->ReturnError(
			ErrorCode    => 'CustomerUserGet.NotCustomerUserData',
			ErrorMessage => "CustomerUserGet: $ErrorMessage",
		);

	}

	# set customer user data into return structure
	$ReturnData->{Data}->{CustomerUser} = \@Item;

	# return result
	return $ReturnData;
}

1;

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
