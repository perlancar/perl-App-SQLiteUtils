package App::SQLiteUtils;

use 5.010001;
use strict;
use warnings;

# AUTHORITY
# DATE
# DIST
# VERSION

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

our %argopt_table = (
    table => {
        schema => 'str*',
    },
);

$SPEC{list_sqlite_tables} = {
    v => 1.1,
    description => <<'_',

See also the `.tables` meta-command of the `sqlite3` CLI.

_
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
    description => <<'_',

See also the `.schema` and `.fullschema` meta-command of the `sqlite3` CLI.

_
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

$SPEC{import_csv_to_sqlite} = {
    v => 1.1,
    summary => 'Import a CSV file into SQLite database',
    description => <<'_',

This tool utilizes the `sqlite3` command-line client to import a CSV file into
SQLite database. It pipes the following commands to the `sqlite3` CLI:

    .mode csv
    .import FILENAME TABLENAME

where FILENAME is the CSV filename and TABLENAME is the table name. If the
`table` option is not specified, the table name will be derived from the CSV
filename (e.g. 'stdin' for '-', 't1' for '/path/to/t1.csv', 'table2' for
'./2.csv' and so on).

_
    args => {
        %args_common,
        csv_file => {
            schema => 'filename*',
            default => '-',
            pos => 1,
        },
        %argopt_table,
    },
    deps => {
        prog => 'sqlite3', # XXX allow customizing path?
    },
};
sub import_csv_to_sqlite {
    my %args = @_;
    my $q;

    my $dbh = _connect(\%args); # just to check/create the db
    $dbh->disconnect; # we're releasing any locks

    open my $h, "| sqlite3 ".String::ShellQuote::shell_quote();
}

1;
# ABSTRACT: Utilities related to SQLite

=head1 DESCRIPTION

This distribution includes several utilities:

#INSERT_EXECS_LIST


=head1 SEE ALSO

L<App::DBIUtils>
