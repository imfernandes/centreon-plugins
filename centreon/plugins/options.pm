#
# Copyright 2015 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package centreon::plugins::options;

use Pod::Usage;
use Pod::Find qw(pod_where);
use Getopt::Long;
Getopt::Long::Configure("pass_through");
Getopt::Long::Configure('bundling');
Getopt::Long::Configure('no_auto_abbrev');
use strict;
use warnings;

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;

    $self->{options_stored} = {};
    $self->{options} = {};
    @{$self->{pod_package}} = ();
    $self->{pod_packages_once} = {};
    return $self;
}

sub set_sanity {
    my ($self, %options) = @_;
    
    Getopt::Long::Configure('no_pass_through');
    $SIG{__WARN__} = sub { 
        $self->{output}->add_option_msg(short_msg => $_[0]);
        $self->{output}->option_exit(nolabel => 1);
    };
}

sub set_output {
    my ($self, %options) = @_;
    
    $self->{output} = $options{output};
}

sub display_help {
    my ($self, %options) = @_;
    
    my $stdout;
    foreach (@{$self->{pod_package}}) {
        
        {
            local *STDOUT;
            open STDOUT, '>', \$stdout;
            pod2usage(-exitval => 'NOEXIT', -input => pod_where({-inc => 1}, $_->{package}),
                      -verbose => 99, 
                      -sections => $_->{sections});
        }
        
        $self->{output}->add_option_msg(long_msg => $stdout) if (defined($stdout));
    }
}

sub add_help {
    my ($self, %options) = @_;
    # $options{package} = string package
    # $options{sections} = string sections
    # $options{help_first} = put at the beginning
    # $options{once} = put help only one time for a package
    
    if (defined($options{once}) && defined($self->{pod_packages_once}->{$options{package}})) {
        return ;
    }
    
    if (defined($options{help_first})) {
        unshift @{$self->{pod_package}}, {package => $options{package}, sections => $options{sections}};
    } else {
        push @{$self->{pod_package}}, { package => $options{package}, sections => $options{sections} };
    }
    
    $self->{pod_packages_once}->{$options{package}} = 1;
}

sub add_options {
    my ($self, %options) = @_;
    # $options{arguments} = ref to hash table with string and name to store (example: { 'mode:s' => { name => 'mode', default => 'defaultvalue' )
    
    foreach (keys %{$options{arguments}}) {
        if (defined($options{arguments}->{$_}->{default})) {
            $self->{options_stored}->{$options{arguments}->{$_}->{name}} = $options{arguments}->{$_}->{default};
        } else {
            $self->{options_stored}->{$options{arguments}->{$_}->{name}} = undef;
        }
        $self->{options}->{$_} = \$self->{options_stored}->{$options{arguments}->{$_}->{name}};
    }
}

sub parse_options {
    my $self = shift;
    #%{$self->{options_stored}} = ();

    GetOptions(
       %{$self->{options}}
    );
    %{$self->{options}} = ();
}

sub get_option {
    my ($self, %options) = @_;

    return $self->{options_stored}->{$options{argument}};
}

sub get_options {
    my $self = shift;

    return $self->{options_stored};
}

sub clean {
    my $self = shift;
    
    $self->{options_stored} = {};
}

1;

__END__
