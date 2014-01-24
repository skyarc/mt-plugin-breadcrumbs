package MT::Plugin::SKR::Breadcrumbs;
#   Breadcrumbs - Supply template tags to generate breadcrumbs easily.
#           Copyright (c) 2009 SKYARC System Co.,Ltd.
#           @see http://www.skyarc.co.jp/engineerblog/entry/breadcrumbs.html

use strict;
use MT 4;
use MT::Placement;
use MT::Category;
use Data::Dumper;#DEBUG

use vars qw( $MYNAME $VERSION );
$MYNAME = 'Breadcrumbs';
$VERSION = '0.03';

use base qw( MT::Plugin );
my $plugin = __PACKAGE__->new({
        name => $MYNAME,
        id => lc $MYNAME,
        key => lc $MYNAME,
        version => $VERSION,
        author_name => 'SKYARC System Co.,Ltd.',
        author_link => 'http://www.skyarc.co.jp/',
        doc_link => 'http://www.skyarc.co.jp/engineerblog/entry/breadcrumbs.html',
        description => <<HTMLHEREDOC,
<__trans phrase="Supply template tags to generate breadcrumbs easily.">
HTMLHEREDOC
});
MT->add_plugin( $plugin );

sub instance { $plugin; }

sub init_registry {
    my $plugin = shift;
    $plugin->registry({
        tags => {
            function => {
                BreadcrumbsTitle => \&_hdlr_breadcrumbs_item,
                BreadcrumbsLink => \&_hdlr_breadcrumbs_item,
            },
            block => {
                Breadcrumbs => \&_hdlr_breadcrumbs,
                BreadcrumbsHeader => \&_hdlr_pass_tokens,
                BreadcrumbsFooter => \&_hdlr_pass_tokens,
            },
        },
    });
}



### Breadcrumbs*
sub _hdlr_breadcrumbs_item {
    my ($ctx, $args) = @_;
    $ctx->stash('breadcrumbs_item')
        ? $ctx->stash('breadcrumbs_item')->{lc $ctx->stash('tag')}
        : $ctx->error(MT->translate(
            "You used an [_1] tag outside of the proper context.",
            '<$MT'. $ctx->stash('tag'). '$>'));
}

### Breadcrumbs
sub _hdlr_breadcrumbs {
    my ($ctx, $args, $cond) = @_;
    my $blog = $ctx->stash('blog')
        or return $ctx->error(MT->translate('No Blog'));

    # Each archive type
    my @items;
    if (!defined $ctx->{archive_type}) {
        my $tmpl = $ctx->stash('template');
        if ($tmpl->outfile !~ m!^index(?:\.\w+)?$!) {
            unshift @items, {
                breadcrumbstitle => $tmpl->name,
                breadcrumbslink => $blog->site_url. $tmpl->outfile,
            };
        }
    }
    elsif ($ctx->{archive_type} =~ /Individual|Page/) {
        my $entry = $ctx->stash('entry')
            or return $ctx->_no_entry_error();
        my $plc = MT::Placement->load({ blog_id => $blog->id, entry_id => $entry->id, is_primary => 1 });
        if ($plc) {
            my $cat = MT::Category->load({ id => $plc->category_id });
            while ($cat) {
                unshift @items, {
                    breadcrumbstitle => $cat->label,
                    breadcrumbslink => $blog->archive_url. $cat->category_path. '/',
                };
                $cat = MT::Category->load({ id => $cat->parent });
            }
        }
        push @items, {
            breadcrumbstitle => $ctx->tag('EntryTitle', $args, $cond),
            breadcrumbslink => $ctx->tag('EntryPermalink', $args, $cond),
        } if $entry->basename !~ m!^index(?:\.\w+)?$!;
    }
    elsif ($ctx->{archive_type} =~ /Category/) {
        my $cat = $ctx->stash('archive_category')
            or return $ctx->error(MT->translate('No categories could be found.'));
        while ($cat) {
            local $ctx->{__stash}{archive_category} = $cat;
            unshift @items, {
                breadcrumbstitle => $ctx->tag('ArchiveTitle', $args, $cond),
                breadcrumbslink => $ctx->tag('ArchiveLink', $args, $cond),
            };
            $cat = MT::Category->load({ id => $cat->parent });
        }
    }
    elsif ($ctx->{archive_type} =~ /Yearly|Monthly|Weekly|Daily/) {
        unshift @items, {
            breadcrumbstitle => $ctx->tag('ArchiveTitle', $args, $cond),
            breadcrumbslink => $ctx->tag('ArchiveLink', $args, $cond),
        };
    }
    elsif ($ctx->{archive_type} =~ /Author/) {
        unshift @items, {
            breadcrumbstitle => $ctx->tag('ArchiveTitle', $args, $cond),
            breadcrumbslink => $ctx->tag('ArchiveLink', $args, $cond),
        };
    }

    # Top
    unshift @items, {
        breadcrumbstitle => $args->{top_label} || 'TOP',
        breadcrumbslink => $blog->site_url,
    } unless $args->{no_top};

    # Reverse
    @items = reverse @items if $args->{reverse};

    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    my $i = 0;
    my $vars = $ctx->{__stash}{vars} ||= {};
    my @outputs;
    foreach my $item (@items) {
        local $vars->{__first__} = !$i;
        local $vars->{__last__} = !defined $items[$i+1];
        local $vars->{__odd__} = ($i % 2) == 0; # 0-based $i
        local $vars->{__even__} = ($i % 2) == 1;
        local $vars->{__counter__} = $i+1;
        local $ctx->{__stash}{breadcrumbs_item} = $item;
        defined (my $out = $builder->build($ctx, $tokens, {
                %$cond,
                BreadcrumbsHeader => $vars->{__first__},
                BreadcrumbsFooter => $vars->{__last__},
        })) or $ctx->error($builder->errstr);
        push @outputs, $out;
        $i++;
    }
    join (($args->{glue} || ''), @outputs);
}

### Pass through tokens
sub _hdlr_pass_tokens {
    my ($ctx, $args, $cond) = @_;
    my $b = $ctx->stash('builder');
    defined(my $out = $b->build($ctx, $ctx->stash('tokens'), $cond))
        or return $ctx->error($b->errstr);
    return $out;
}

1;
__END__