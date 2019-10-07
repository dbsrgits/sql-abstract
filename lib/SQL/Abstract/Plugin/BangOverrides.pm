package SQL::Abstract::Plugin::BangOverrides;

use Moo;

with 'SQL::Abstract::Role::Plugin';

sub register_extensions {
  my ($self, $sqla) = @_;
  foreach my $stmt ($sqla->statement_list) {
    $sqla->wrap_expander($stmt => sub {
      my ($orig) = @_;
      sub {
        my ($self, $name, $args) = @_;
        my %args = (
          %$args,
          (ref($args->{order_by}) eq 'HASH'
            ? %{$args->{order_by}}
            : ())
        );
        my %overrides;
        foreach my $clause (map /^!(.*)$/, keys %args) {
          my $override = delete $args{"!${clause}"};
          $overrides{$clause} = (
            ref($override) eq 'CODE'
              ? $self->$override($args{$clause})
              : $override
          );
        }
        $self->$orig($name, { %$args, %overrides });
      }
    });
  }
}

1;
