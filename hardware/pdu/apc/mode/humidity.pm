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

package hardware::pdu::apc::mode::humidity;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

my %states = (
    1 => ['notPresent', 'OK'],
    2 => ['belowMin', 'CRITICAL'],
    3 => ['belowLow', 'WARNING'],
    4 => ['normal', 'OK'],
    5 => ['aboveHigh', 'WARNING'],
    6 => ['aboveMax', 'CRITICAL'],
);

my %type = (
    1 => 'temperatureOnly',
    2 => 'temperatureHumidity'
);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
                                {
                                    "warning:s"         => { name => 'warning', },
                                    "critical:s"        => { name => 'critical', },
                                });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);

    if (($self->{perfdata}->threshold_validate(label => 'warning', value => $self->{option_results}->{warning})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong warning threshold '" . $self->{option_results}->{warning} . "'.");
        $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'critical', value => $self->{option_results}->{critical})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong critical threshold '" . $self->{option_results}->{critical} . "'.");
        $self->{output}->option_exit();
    }
}

sub run {
    my ($self, %options) = @_;
    # $options{snmp} = snmp object
    $self->{snmp} = $options{snmp};

    my $oid_rPDU2SensorTempHumidityStatusName = '.1.3.6.1.4.1.318.1.1.26.10.2.2.1.3';
    my $oid_rPDU2SensorTempHumidityStatusNumber = '.1.3.6.1.4.1.318.1.1.26.10.2.2.1.4';
    my $oid_rPDU2SensorTempHumidityStatusType = '.1.3.6.1.4.1.318.1.1.26.10.2.2.1.5';
    my $oid_rPDU2SensorTempHumidityStatusRelativeHumidity = '.1.3.6.1.4.1.318.1.1.26.10.2.2.1.10';
    my $oid_rPDU2SensorTempHumidityStatusHumidityStatus = '.1.3.6.1.4.1.318.1.1.26.10.2.2.1.11';

    $self->{results} = $self->{snmp}->get_multiple_table(oids => [
                                                            { oid => $oid_rPDU2SensorTempHumidityStatusName },
                                                            { oid => $oid_rPDU2SensorTempHumidityStatusNumber },
                                                            { oid => $oid_rPDU2SensorTempHumidityStatusType },
                                                            { oid => $oid_rPDU2SensorTempHumidityStatusRelativeHumidity },
                                                            { oid => $oid_rPDU2SensorTempHumidityStatusHumidityStatus },
                                                         ],
                                                         , nothing_quit => 1);

    
    $self->{output}->output_add(severity => 'OK',
                                short_msg => 'All humidity sensors are ok');

    foreach my $oid (keys %{$self->{results}->{ $oid_rPDU2SensorTempHumidityStatusName}}) {    
        $oid =~ /\.([0-9]+)$/;
        my $instance = $1;

        next if ($self->{results}->{$oid_rPDU2SensorTempHumidityStatusType}->{$oid_rPDU2SensorTempHumidityStatusType . '.' . $instance} == 1);
        
        my $sensor_name = $self->{results}->{ $oid_rPDU2SensorTempHumidityStatusName}->{$oid};
        my $sensor_number = $self->{results}->{$oid_rPDU2SensorTempHumidityStatusNumber}->{$oid_rPDU2SensorTempHumidityStatusNumber . '.' . $instance};
        my $sensor_humidity = $self->{results}->{$oid_rPDU2SensorTempHumidityStatusRelativeHumidity}->{$oid_rPDU2SensorTempHumidityStatusRelativeHumidity . '.' . $instance};
        my $sensor_status = $self->{results}->{$oid_rPDU2SensorTempHumidityStatusHumidityStatus}->{$oid_rPDU2SensorTempHumidityStatusHumidityStatus . '.' . $instance};
        
        $self->{output}->output_add(long_msg => sprintf("Humidity sensor #%d '%s' is '%d%%'", 
                                            $sensor_number, $sensor_name, $sensor_humidity));
		$self->{output}->perfdata_add(label => 'hum' . $sensor_number,
                                      unit => '%',
                                      value => $sensor_humidity,
                                      warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning'),
                                      critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical'),
                                      min => 0,
                                      max => 100);
                                      
        my $exit = $self->{perfdata}->threshold_check(value => $sensor_humidity, 
                                                      threshold => [ { label => 'critical', 'exit_litteral' => 'critical' }, { label => 'warning', exit_litteral => 'warning' } ]);
                                                      
		if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
             $self->{output}->output_add(severity => $exit,
                                        short_msg => sprintf("Temperature sensor #%d '%s' is '%d%%'", 
                                                             $sensor_number, $sensor_name, $sensor_humidity));
        }
    }
    
    $self->{output}->display();
    $self->{output}->exit();
}

1;

__END__

=head1 MODE

Check APC humidity sensors.

=over 8

=back

=cut
    
