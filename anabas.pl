#!/usr/bin/perl

use File::Basename;
use File::Spec::Functions;
use Getopt::Long;

$current_categ='?';
$def_categ='C';
$debug=0;
$round_offs=0;
GetOptions('def_categ=s'=>\$def_categ,
           'round_offset=i'=>\$round_offs,
           'verbose=i'=>\$debug);
if (@ARGV)
  { if (-d @ARGV[0])
      { $directory=@ARGV[0];
       }
    else
      { @bunch=@ARGV;
        $directory=dirname($bunch[0]);
       }
   }
else
  { $directory='.';
   }
if (!@bunch)
  { opendir(D,$directory);
    while ($file=readdir(D))
      { $path=catfile($directory,$file);
        next unless (-f $path);
        next unless ($file=~/^st\d+\.txt$/i);
        push @bunch,$path;
       }
    closedir D;
   }
@used_categ=();
%all_motor=();
%all_a2a=();
%all_a2b=();
%all_b2b=();
%all_b2a=();
foreach $file (@bunch)
  { if ($file=~/(.+)\.([^.]+)$/)
      { $output=$1.'.html';
       }
    else
      { $output='-';
       }
    die "$file: $!" unless open(F,$file);
#    print "$file\n";
    $prev_round=0;
    $is_open=0;
    $sum={};
    $categ='';
    $line_nb=0;
    $in_html=0;
    $in_table=0;
    $line=<F>;
    $line_nb++;
    chomp $line;
    print "$line\n" if $debug;
NEW:
    while ($line!~/^--------/)
      { $line=<F>;
        goto TERM if eof F;
        $line_nb++;
        print "$line\n" if $debug;
       }
    $line=<F>;
    chomp $line;
    next if eof F;
    $line_nb++;
    $title=$line;
    print "$line\n" if $debug;
###    6 Van Tricht Luc                B
    if ($title=~/^\s+(\d+) (.{25}) (.+)$/)
      { $racer=$1;
        $name=$2;
        $trail=$3;
        $channel=substr($trail,0,3);
        $categ=substr($trail,4,1);
        $club=substr($trail,6);
        $categ=$def_categ unless ($categ=~/[ABC]/);
        if ($debug)
          { print "racer=$racer\n";
            print "name=$name\n";
            print "trail=$trail\n";
            print "channel=$channel\n";
            print "categ=$categ\n";
            print "club=$club\n";
           }
        $title=$categ.':'.$racer.' '.$name.' ('.$club.')';
        $ident=[$file,$categ,$name,$club,$output];
       }
    else
      { $categ='';
        $racer=99;
        $ident=[$file,'',$title];
       }
    &get_lim($categ);
    $started=0;
    $mean=[];
    while ($line=<F>)
      { chomp $line;
        $line_nb++;
        print "$line\n" if $debug;
        goto NEW if ($line=~/^-------/);
        next unless ($line);
        next unless ($line=~/[^\s]/);
###  Durchgang 1
        if (!$started && $line=~/Durchgang (\d+)/)
          { $round=$1;
            $engaged=0;
            if ($round_offs)
              { while (exists ${$sum}{$round})
                  { $round+=$round_offs;
                    print "round=$round\n" if $debug;
                   }
               }
           }
###Info 0000000002 1
        elsif (!$started && ($line=~/Info/ || $line=~/GSinfo/))
          { next;
           }
        else
          { next unless ($line=~/^([^\d]+)([\d\.]+) (.?) ([^\s]+) (.+)$/);
            $chrono=$2;
            $base=$3;
            $event=$4;
            $other=$5;
###     !  0.00 A Start Sun Jun 17 10:59:26
            if ($event=~/Start/)
              { goto NEW if ($started);
#                if ($is_open && ($round<$prev_round || $round==1))
#                  { close O;
#                    $is_open=0;
#                    $in_html=0;
#                    $in_table=0;
#                    $sum={};
#                   }
                $prev_round=$round;
                $started=$other;
                $MotorEin=$chrono;
                $ThisMotor=0;
                $FirstA=0;
                $LastA=0;
                $A2A=0;
                $A2B=0;
                $FirstB=0;
                $LastB=0;
                $B2B=0;
                $B2A=0;
                $engaged=0;
                $running=1;
                $last_base=' ';
               }
###     ! 24.29 - Motor Ein 5 #2
###     ! 29.07 - Motor Aus 10 #2
            elsif ($event=~/Motor/)
##              { goto NEW if ($other!~/([^\s]+) (\d+) (.+)$/);
              { goto NEW if ($other!~/([^\s]+)/);
                $sw_mode=$1;
                if ($sw_mode=~/Ein/ || $sw_mode=~/on/)
                  { if ($engaged || $ThisMotor)
                      { &out(1);
                        $ThisMotor=0;
                        $FirstA=0;
                        $LastA=0;
                        $A2A=0;
                        $FirstB=0;
                        $LastB=0;
                        $B2B=0;
                        $B2A=0;
                        $A2B=0;
                        $engaged=0;
                        $last_base=' ';
                       }
                    $MotorEin=$chrono;
                    $running=1;
                   }
                elsif ($sw_mode=~/Aus/ || $sw_mode=~/off/)
                  { if ($running)
                      { $MotorAus=$chrono;
                        $ThisMotor=$MotorAus-$MotorEin;
                        $running=0;
                       }
                    $last_base=' ';
                   }
                elsif ($sw_mode=~/disrub/)
                  { next;
                   }
                else
                  { goto NEW;
                   }
               }
###       29.23 A Strecke  4  sz:   5.2
###       32.09 B Strecke  5  sz:   2.9
###       33.08 B Strecke  5  sz:   1.0
###       36.98 A Strecke  6  sz:   3.9
###       37.47 A Strecke  6  sz:   0.5
            elsif ($event=~/Strecke/)
              { goto NEW if ($other!~/^\s*([\d]+) /);
                $this_strecke=$1;
                if (!$running)
                  { if (uc($base) eq 'A')
                      { if (uc($last_base) eq 'B')
                          { $FirstA=$chrono;
                            $B2A=$FirstA-$LastB;
                            &out(1);
                            $ThisMotor=0;
                            $FirstA=$chrono;
                            $LastA=$chrono;
                            $A2A=0;
                            $FirstB=0;
                            $LastB=0;
                            $B2B=0;
                            $B2A=0;
                            $A2B=0;
                            $engaged=0;
                           }
                        elsif (uc($last_base) eq 'A')
                          { $LastA=$chrono;
                            $A2A=$LastA-$FirstA;
                            $engaged=1;
                           }
                        else
                          { $engaged=1;
                            $FirstA=$chrono;
                            $LastA=$chrono;
                           }
                       } 
                    elsif (uc($base) eq 'B')
                      { if (uc($last_base) eq 'B')
                          { $LastB=$chrono;
                            $B2B=$LastB-$FirstB;
                            $engaged=1;
                           }
                        elsif (uc($last_base) eq 'A')
                          { $FirstB=$chrono;
                            $A2B=$FirstB-$LastA;
                            $LastB=$chrono;
                            $B2B=0;
                            $engaged=1;
                           }
                        else
                          { $FirstB=$chrono;
                            $LastB=$chrono;
                            $B2B=0;
                            $engaged=1;
                           }
                       }
                    else
                      { goto NEW;
                       }
                    $last_base=$base;
                   }
               }
###      200.00   Ende Sun Jun 17 11:02:46
            elsif ($event=~/Ende/)
              { if ($engaged)
                  { &out(1);
                    $engaged=0;
                   }
                &close_table();
                ${$sum}{$round}=$mean;
                goto NEW;
               }
            elsif ($event=~/Servopos/)
              { next;
               }
            else
              { goto NEW;
               }
           }
       }
TERM:
    &close_table();
    ${$sum}{$round}=$mean if ($started);
    ${$summaries}{$racer}=$sum;
    ${$identities}{$racer}=$ident;
    &close_html();
    close(F);
    close(O);
   }
$file=catfile($directory,'index.html');
open(O,">$file");
print O "<html>\n";
print O "<head>\n";
print O "<title>Mean times summary</title>\n";
print O "</head><body>\n";
print O "<H1>Mean times summary</H1>\n";
$is_open=1;
print O "<H3>Flagging triggers and median values</H3>\n";
print O "<center><table border>\n";
print O "<tr><th>Category</th>\n";
print O "<th colspan=\"3\">MotorTot</th>\n";
print O "<th colspan=\"3\">A turn</th>\n";
print O "<th colspan=\"3\">A to B</th>\n";
print O "<th colspan=\"3\">B turn</th>\n";
print O "<th colspan=\"3\">B to A</th>\n";
print O "</tr>\n";
foreach $categ (sort @used_categ)
  { &get_lim($categ);
    print O "<tr>\n";
    print O "<td align=\"center\">$categ</td>\n";
    printf O "<td bgcolor=\"green\">%.2f</td>\n",$lim_mot[1];
    @all=sort {$a <=> $b} @{$all_motor{$categ}};
    $median=0;
    $n_all=@all;
    if ($n_all)
      { for ($i=0;$i<$n_all;$i++)
          { $median+=$all[$i];
           }
        $median=$median/$n_all;
        printf O "<td>%.2f</td>\n",$median;
       }
    else
      { print O "<td> </td>\n";
       }
    printf O "<td bgcolor=\"red\">%.2f</td>\n",$lim_mot[0];
    printf O "<td bgcolor=\"green\">%.2f</td>\n",$lim_a2a[1];
    @all=sort {$a <=> $b} @{$all_a2a{$categ}};
    $n_all=int(@all/3);
    if ($n_all>2)
      { $median=0;
        for ($i=$n_all;$i<($n_all*2);$i++)
          { $median+=$all[$i];
           }
        $median=$median/$n_all;
        printf O "<td>%.2f</td>\n",$median;
       }
    else
      { print O "<td> </td>\n";
       }
    printf O "<td bgcolor=\"red\">%.2f</td>\n",$lim_a2a[0];
    printf O "<td bgcolor=\"green\">%.2f</td>\n",$lim_a2b[1];
    @all=sort {$a <=> $b} @{$all_a2b{$categ}};
    $n_all=int(@all/3);
    if ($n_all>2)
      { $median=0;
        for ($i=$n_all;$i<($n_all*2);$i++)
          { $median+=$all[$i];
           }
        $median=$median/$n_all;
        printf O "<td>%.2f</td>\n",$median;
       }
    else
      { print O "<td> </td>\n";
       }
    printf O "<td bgcolor=\"red\">%.2f</td>\n",$lim_a2b[0];
    printf O "<td bgcolor=\"green\">%.2f</td>\n",$lim_b2b[1];
    @all=sort {$a <=> $b} @{$all_b2b{$categ}};
    $n_all=int(@all/3);
    if ($n_all>2)
      { $median=0;
        for ($i=$n_all;$i<($n_all*2);$i++)
          { $median+=$all[$i];
           }
        $median=$median/$n_all;
        printf O "<td>%.2f</td>\n",$median;
       }
    else
      { print O "<td> </td>\n";
       }
    printf O "<td bgcolor=\"red\">%.2f</td>\n",$lim_b2b[0];
    printf O "<td bgcolor=\"green\">%.2f</td>\n",$lim_b2a[1];
    @all=sort {$a <=> $b} @{$all_b2a{$categ}};
    $n_all=int(@all/3);
    if ($n_all>2)
      { $median=0;
        for ($i=$n_all;$i<($n_all*2);$i++)
          { $median+=$all[$i];
           }
        $median=$median/$n_all;
        printf O "<td>%.2f</td>\n",$median;
       }
    else
      { print O "<td> </td>\n";
       }
    printf O "<td bgcolor=\"red\">%.2f</td>\n",$lim_b2a[0];
    print O "</tr>\n";
   }
print O "</table></center>\n";
print O "<p>\n";
foreach $racer (sort {$a <=> $b} keys(%{$identities}))
  { $ident=${$identities}{$racer};
    $file=${$ident}[0];
    $categ=${$ident}[1];
    $name=${$ident}[2];
    $club=${$ident}[3];
    $output=${$ident}[4];
    next unless ($output);
    print O "<H3>$categ:$racer $name ($club)</H3>\n";
#    print "$output\n";
    $output=basename($output);
    $file=basename($file);
    print O "<center> <a href=$output>$file</a>\n";
    print O "<table border>\n";
    print O "<tr>\n";
    print O "<th>Round</th>\n";
    print O "<th>Bases</th>\n";
    print O "<th>MotorTot</th>\n";
    print O "<th>A turn</th>\n";
    print O "<th>A to B</th>\n";
    print O "<th>B turn</th>\n";
    print O "<th>B to A</th>\n";
    print O "</tr>\n";
    &get_lim($categ);
    $sum=${$summaries}{$racer};
    foreach $round (sort keys(%{$sum}))
      { $mean=${$sum}{$round};
        $term_base=${$mean}[0];
        $ThisMotor=${$mean}[1];
        $A2A=${$mean}[2];
        $A2B=${$mean}[3];
        $B2B=${$mean}[4];
        $B2A=${$mean}[5];
        print O "<tr>\n";
        print O "<td align=\"center\">$round</td>\n";
        print O "<td align=\"right\">";
        if ($term_base)
          { print O "$term_base</td>\n";
           }
        else
          { print O " </td>\n";
           }
        &colorize($ThisMotor,1,$lim_mot[0],$lim_mot[1]);
        &colorize($A2A,1,$lim_a2a[0],$lim_a2a[1]);
        if (!$A2A)
          { &colorize($A2B,1,$lim_a2a[0]+$lim_a2b[0],
                                 $lim_a2a[1]+$lim_a2b[1]);
           }
        else
          { &colorize($A2B,1,$lim_a2b[0],$lim_a2b[1]);
           }
        &colorize($B2B,1,$lim_b2b[0],$lim_b2b[1]);
        if ($B2B)
          { &colorize($B2A,1,$lim_b2a[0],$lim_b2a[1]);
           }
        else
          { &colorize($B2A,1,$lim_b2b[0]+$lim_b2a[0],
                                $lim_b2b[1]+$lim_b2a[1]);
           }
        print O "</tr>\n";
       }
    print O "</table></center>\n";
    print O "<p>\n";
   }
print O "</body>\n";
print O "</html>\n";
close O;

sub get_lim
  { local($categ)=@_;
    local($file,$line);

    if ($categ ne $current_categ)
      { $current_categ=$categ;
        @lim_a2a=(0,0);
        @lim_a2b=(0,0);
        @lim_b2b=(0,0);
        @lim_b2a=(0,0);
        @lim_mot=(0,0);
        return unless $categ;
        push @used_categ,$categ unless grep(/$categ/,@used_categ);
        $file='LIMIT_'.$categ.'.txt';
        $file=catfile($directory,"LIMIT_$categ.txt");
        $file='LIMIT_'.$categ.'.txt' unless (-s $file);
        return unless (open(L,$file));
        while ($line=<L>)
          { chomp $line;
            next unless ($line=~/^([^\s]+)\s+([\d\.]+)\s+([\d\.]+)/);
            if ($1 eq 'A2A')
              { @lim_a2a=($2,$3);
               }
            elsif ($1 eq 'A2B')
              { @lim_a2b=($2,$3);
               }
            elsif ($1 eq 'B2B')
              { @lim_b2b=($2,$3);
               }
            elsif ($1 eq 'B2A')
              { @lim_b2a=($2,$3);
               }
            elsif ($1 eq 'MOT')
              { @lim_mot=($2,$3);
               }
           }
        close L;
       }
   }

sub colorize
  { local($value,$flag,$lim_max,$lim_min)=@_;

    if ($value)
      { print O "<td align=\"right\"";
        if ($flag && $lim_max && $value>=$lim_max)
          { print O " bgcolor=\"red\"";
           }
        elsif ($flag && $lim_min && $value<$lim_min)
          { print O " bgcolor=\"green\"";
           }
        printf O ">%.2f</td>\n",$value;
       }
    else
      { print O "<td> </td>\n";
       }
   }

sub out
  { local($flag)=@_;
    local($distance)=150;
    local($ms2kmh)=3.6;
 
    if (!$is_open)
      { open(O,">$output");
        $is_open=1;
       }
    if (!$in_html)
      { print O "<html>\n";
        print O "<head>\n";
        print O "<title>$title</title>\n";
        print O "</head><body>\n";
        print O "<H1>$title</H1>\n";
        $in_html=1;
       }
    if (!$in_table)
      { print O "<center><H3>$started : Round $round</H3>\n";
        print O "<table border>\n";
        print O "<tr>\n";
        print O "<th>Motor</th>\n";
        print O "<th>A turn</th>\n";
        print O "<th>A to B</th>\n";
        print O "<th>Km/h</th>\n";
        print O "<th>B turn</th>\n";
        print O "<th>B to A</th>\n";
        print O "<th>Km/h</th>\n";
        print O "<th>Chrono</th>\n";
        print O "<th>Base</th>\n";
        print O "</tr>\n";
        $in_table=1;
        $Tot_motor=0;
        $N_motor=0;
        $Tot_a2a=0;
        $N_a2a=0;
        $Tot_b2b=0;
        $N_b2b=0;
        $Tot_a2b=0;
        $N_a2b=0;
        $Tot_b2a=0;
        $N_b2a=0;
       }
     print O "<tr>\n";
     &colorize($ThisMotor,!$flag,$lim_mot[0],$lim_mot[1]);
     &colorize($A2A,$flag,$lim_a2a[0],$lim_a2a[1]);
     if (!$ThisMotor && !$A2A)
       { &colorize($A2B,$flag,$lim_a2a[0]+$lim_a2b[0],
                                  $lim_a2a[1]+$lim_a2b[1]);
        }
     else
       { &colorize($A2B,$flag,$lim_a2b[0],$lim_a2b[1]);
        }
     if ($flag && $A2B)
       { $km=$distance*$ms2kmh/$A2B;
         printf O "<td align=\"right\">%d</td>\n",$km;
        }
     else
       { print O "<td> </td>\n";
        }
     &colorize($B2B,$flag,$lim_b2b[0],$lim_b2b[1]);
     if ($B2B)
       { &colorize($B2A,$flag,$lim_b2a[0],$lim_b2a[1]);
        }
     else
       { &colorize($B2A,$flag,$lim_b2b[0]+$lim_b2a[0],
                                $lim_b2b[1]+$lim_b2a[1]);
        }
     if ($flag && $B2A)
       { $km=$distance*$ms2kmh/$B2A;
         printf O "<td align=\"right\">%d</td>\n",$km;
        }
     else
       { print O "<td> </td>\n";
        }
     printf O "<td align=\"right\">%.2f</td>\n",$chrono;
     print O "<td align=\"right\">$this_strecke</td>\n";
     print O "</tr>\n";
     if ($flag)
       { if ($ThisMotor)
           { $Tot_motor+=$ThisMotor;
             $N_motor++;
#             push @{$all_motor{$categ}},$ThisMotor;
            }
         if ($A2A)
           { $Tot_a2a+=$A2A;
             $N_a2a++;
             push @{$all_a2a{$categ}},$A2A;
            }
         if ($A2B)
           { $Tot_a2b+=$A2B;
             $N_a2b++;
             push @{$all_a2b{$categ}},$A2B;
            }
         if ($B2B)
           { $Tot_b2b+=$B2B;
             $N_b2b++;
             push @{$all_b2b{$categ}},$B2B;
            }
         if ($B2A)
           { $Tot_b2a+=$B2A;
             $N_b2a++;
             push @{$all_b2a{$categ}},$B2A;
            }
        }
   }

sub close_table
  { local($term_base);

    if ($in_table)
      { $ThisMotor=$Tot_motor;
        $A2A=$Tot_a2a;
        $A2B=$Tot_a2b;
        $B2B=$Tot_b2b;
        $B2A=$Tot_b2a;
        $term_base=$this_strecke;
        $this_strecke='TOTAL';
        &out(0);
        if ($N_motor)
          { $ThisMotor=$Tot_motor/$N_motor;
           }
        else
          { $ThisMotor=0;
           }
        if ($N_a2a)
          { $A2A=$Tot_a2a/$N_a2a;
           }
        else
          { $A2A=0;
           }
        if ($N_a2b)
          { $A2B=$Tot_a2b/$N_a2b;
           }
        else
          { $A2B=0;
           }
        if ($N_b2b)
          { $B2B=$Tot_b2b/$N_b2b;
           }
        else
          { $B2B=0;
           }
        if ($N_b2a)
          { $B2A=$Tot_b2a/$N_b2a;
           }
        else
          { $B2A=0;
           }
        push @{$all_motor{$categ}},$Tot_motor;
        $mean=[$term_base,$Tot_motor,$A2A,$A2B,$B2B,$B2A];
        $this_strecke='MEAN';
        &out(1);
        print O "</table></center>\n";
        print O "<p>\n";
        $in_table=0;
       }
   }

sub close_html
  {
    if ($in_html)
      { print O "</body>\n";
        print O "</html>\n";
        $in_html=0;
       }
   }
