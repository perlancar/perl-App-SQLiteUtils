package App::SQLiteUtils;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

sub _connect {
    my $args = shift;
    DBI->connect("dbi:SQLite:dbname=$args->{db_file}", undef, undef, {RaiseError=>1});
}

our %args_common = (
    db_file => {
        schema => 'filename*',
        req => 1,
        pos => 0,
    },
);

our %arg1_table = (
    table => {
        schema => 'str*',
        req => 1,
        pos => 1,
    },
);

$SPEC{list_sqlite_tables} = {
    v => 1.1,
    args => {
        %args_common,
    },
    result_naked => 1,
};
sub list_sqlite_tables {
    require DBI;
    require DBIx::Util::Schema;

    my %args = @_;
    my $dbh = _connect(\%args);
    [DBIx::Util::Schema::list_tables($dbh)];
}

$SPEC{list_sqlite_columns} = {
    v => 1.1,
    args => {
        %args_common,
        %arg1_table,
    },
    result_naked => 1,
};
sub list_sqlite_columns {
    require DBI;
    require DBIx::Util::Schema;

    my %args = @_;
    my $dbh = _connect(\%args);
    [DBIx::Util::Schema::list_columns($dbh, $args{table})];
}

1;
# ABSTRACT: Utilities related to SQLite

=head1 DESCRIPTION

This distribution includes several utilities:

#INSERT_EXECS_LIST


=head1 SEE ALSO

L<App::DBIUtils>
