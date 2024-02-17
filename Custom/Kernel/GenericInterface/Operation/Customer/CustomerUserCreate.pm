# --
# Kernel/GenericInterface/Operation/Customer/CustomerUserCreate.pm - GenericInterface CustomerUser operation backend
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::GenericInterface::Operation::Customer::CustomerUserCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use parent qw(
  Kernel::GenericInterface::Operation::Common
  Kernel::GenericInterface::Operation::Customer::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::Customer::CustomerUserCreate - GenericInterface CustomerUser operation backend

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
            CustomerUser => {
                Source         => 'CustomerUser2'        # not required, set to default 'CustomerUser' if not specified
				UserFirstname  => 'Huber',               # required
				UserLastname   => 'Manfred',             # required
				UserCustomerID => 'A124',                # not required
				UserLogin      => 'mhuber',              # required
				UserPassword   => 'some-pass',           # not required
				UserEmail      => 'email@example.com',   # required
            },
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        ErrorMessage => '',                               # In case of an error
        Data => {
            CustomerUserID  => 'mhuber'
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
		ErrorCode    => 'CustomerUserCreate.AuthFail',
		ErrorMessage => "CustomerUser: Authorization failing!",
	) if !$UserID;

    # check needed hashes
	for my $Needed (qw(CustomerUser)) {
		if ( !IsHashRefWithData( $Param{Data}->{$Needed} ) ) {
			return $Self->ReturnError(
				ErrorCode    => 'CustomerUserCreate.MissingParameter',
				ErrorMessage => "CustomerUserCreate: $Needed  parameter is missing or not valid!",
			);
		}
	}

	for my $Needed (qw(UserLogin UserLastname UserFirstname UserEmail)) {
		if ( !$Param{Data}->{CustomerUser}->{$Needed} ) {
			return $Self->ReturnError(
				ErrorCode    => 'CustomerUserCreate.MissingParameter',
				ErrorMessage => "CustomerUserCreate: CustomerUser->$Needed parameter is missing!",
            );
		}
	}
	return $Self->_CustomerUserAdd(
		CustomerUser     => $Param{Data}->{CustomerUser},
		UserID           => $UserID,
	);
}

=begin Internal:

=head2 _CustomerUserAdd()

add a CustomerUser

    my $Response = $OperationObject->_CustomerUserAdd(
        CustomerUser => $CustomerUser,         # all CustomerUser parameters
        UserID          => 123,
    );

    returns:

    $Response = {
        Success => 1,                               # if everything is OK
        Data => {
            CustomerUserID     => 'specifieduserlogin', 
        }
    }

    $Response = {
        Success      => 0,                         # if unexpected error
        ErrorMessage => "$Param{ErrorCode}: $Param{ErrorMessage}",
    }

=cut

sub _CustomerUserAdd {

    my ( $Self, %Param ) = @_;

	# isolate CustomerUser parameters
	my $CustomerUser = $Param{CustomerUser};

	# remove leading and trailing spaces
	for my $Attribute ( sort keys %{$CustomerUser} ) {
		if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

			#remove leading spaces
			$CustomerUser->{$Attribute} =~ s{\A\s+}{};

			#remove trailing spaces
			$CustomerUser->{$Attribute} =~ s{\s+\z}{};
		}
	}

    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

	# check CustomerUserSource
    my %CustomerUserSources = $CustomerUserObject->CustomerSourceList();

	return $Self->ReturnError(
		ErrorCode    => 'CustomerUserCreate.ValidateSource',
		ErrorMessage => "CustomerUserCreate: Source is invalid!",
	) if defined $CustomerUser->{Source} && !defined $CustomerUserSources{ $CustomerUser->{Source} };
    

    # check given UserLogin
	my %User = $CustomerUserObject->CustomerUserDataGet(
        User => $CustomerUser->{UserLogin},
    );
	return $Self->ReturnError(
		ErrorCode => 'CustomerUserCreate.ValidateUserLogin',
		ErrorMessage =>"CustomerUserCreate: UserLogin already exist!",
    ) if (%User);

	# check UserEmail
    my $CheckItemObject = $Kernel::OM->Get('Kernel::System::CheckItem');
    my $ValidateEmail = $CheckItemObject->CheckEmail( 
        Address => $CustomerUser->{UserEmail} ,
    );

	return $Self->ReturnError(
		ErrorCode    => 'CustomerUserUpdate.EmailValidate',
		ErrorMessage => "CustomerUserUpdate: Email address (" . $CustomerUser->{UserEmail} . ") not valid (". $CheckItemObject->CheckError() . ")!",
	) if !$ValidateEmail;

	my %Result = $CustomerUserObject->CustomerSearch(
		Valid            => 0,
		PostMasterSearch => $CustomerUser->{UserEmail},
	);

	return $Self->ReturnError(
		ErrorCode    => 'CustomerUserUpdate.EmailInUse',
		ErrorMessage => "CustomerUserUpdate: Email address (" . $CustomerUser->{UserEmail} . ") already in use for another customer user!",
	) if (%Result);

	# check given CustomerID
	return $Self->ReturnError(
		ErrorCode => 'CustomerUserCreate.ValidateCompany',
		ErrorMessage =>"CustomerUserCreate: UserCustomerID does not exist!",
	) if defined $CustomerUser->{UserCustomerID} && !$Self->ValidateCustomerCompany( CustomerID => $CustomerUser->{UserCustomerID} );

    # set UserEmail as CustomerID if not given
    $CustomerUser->{UserCustomerID} = $CustomerUser->{UserCustomerID} || $CustomerUser->{UserEmail};
    $CustomerUser->{ValidID} = 1;
    $CustomerUser->{UserID} = $Param{UserID};

	my $CustomerUserID = $CustomerUserObject->CustomerUserAdd(
        %{$CustomerUser},
	);

	return $Self->ReturnError(
		ErrorCode => 'CustomerUserCreate.Error',
		ErrorMessage =>"CustomerUserCreate: Could not create, please contact system administrator!",
    ) if !$CustomerUserID;


	return {
        Success => 1,
        Data => {
            CustomerUserID => $CustomerUserID,
        },
    };
}

1;

=end Internal:

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
