# --
# Kernel/System/Ticket/Event/TitlePrefixByRecipient.pm - Add a prefix to the ticket title based on the original recipient.
# Copyright (C) 2016 Perl-Services.de, http://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::TitlePrefixByRecipient;

use strict;
use warnings;

use Kernel::System::EmailParser;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    for my $Object( qw(ConfigObject TicketObject LogObject EncodeObject) ) {
        $Self->{$Object} = $Param{$Object} || die "Got no $Object!";
    }

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Self->{LogObject};
    my $TicketObject = $Self->{TicketObject};
    my $ConfigObject = $Self->{ConfigObject};

    # check needed stuff
    for my $Needed (qw(Data Event Config UserID)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }

    for my $NeededData (qw(TicketID ArticleID)) {
        if ( !$Param{Data}->{$NeededData} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $NeededData in Data!",
            );

            return;
        }
    }

    my @Index = $TicketObject->ArticleIndex(
        TicketID => $Param{Data}->{TicketID},
    );

    # add prefix iff this is the first article
    return 1 if @Index > 1;

    my %Article = $TicketObject->ArticleGet(
        ArticleID     => $Param{Data}->{ArticleID},
        UserID        => $Param{UserID},
        DynamicFields => 0,
    );

    # only tickets created via mail by customer are checked
    return 1 if $Article{SenderType} ne 'customer';
    return 1 if $Article{ArticleType} ne 'email-external';

    my %Addresses = %{ $ConfigObject->Get('TicketTitlePrefixByRecipient::Addresses') || {} };

    return 1 if !%Addresses;

    # get plain address
    my $Parser = Kernel::System::EmailParser->new(
        %{$Self},
        Mode => 'Standalone',
    );

    my @LineAddresses = $Parser->SplitAddressLine( Line => $Article{To} );
    my $UseAddress;

    LINEADDRESS:
    for my $LineAddress ( @LineAddresses ) {
        my $PlainAddress = $Parser->GetEmailAddress(
            Email => $LineAddress,
        );

        next LINEADDRESS if !$PlainAddress;
        next LINEADDRESS if !$Addresses{$PlainAddress};

        $UseAddress = $PlainAddress;
        last LINEADDRESS;
    }


    return 1 if !$UseAddress;

    my $Prefix   = $Addresses{$UseAddress};
    my $NewTitle = $Prefix . ' ' . $Article{Title};

    $TicketObject->TicketTitleUpdate(
        TicketID => $Param{Data}->{TicketID},
        Title    => $NewTitle,
        UserID   => $Param{UserID},
    );

    return 1;
}

1;
