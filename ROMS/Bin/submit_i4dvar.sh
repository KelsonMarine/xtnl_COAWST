#!/bin/bash
#
# git $Id$
# svn $Id: submit_i4dvar.sh 1151 2023-02-09 03:08:53Z arango $
#######################################################################
# Copyright (c) 2002-2023 The ROMS/TOMS Group                         #
#   Licensed under a MIT/X style license                              #
#   See License_ROMS.txt                                              #
################################################## Hernan G. Arango ###
#                                                                     #
#  Shallow Water Acustics 2006 Experiment:                            #
#                                                                     #
#  This script is use to run ROMS incremental 4DVar algorithm in      #
#  sequential mode through several assimilation cycles. The user      #
#  needs to have the following directory structure:                   #
#                                                                     #
#    $MYROOT/                                                         #
#    $MYROOT/Data                                                     #
#    $MYROOT/Forward                                                  #
#    $MYROOT/I4DVAR                                                   #
#    $MYROOT/OBS                                                      #
#                                                                     #
#  and storage directory:                                             #
#                                                                     #
#    $STORAGE                                                         #
#                                                                     #
#  To submit a job in the batch queue.  Use the following command     #
#  in MPI applications to avoid running on the head node NO_LOCAL:    #
#                                                                     #
#      batch now -f submit_i4dvar.sh                                  #
#                                                                     #
#  To check batch use:                                                #
#                                                                     #
#      bbq                                                            #
#                                                                     #
#######################################################################

echo "  "
echo "**************************************************************"
echo "***     ROMS/TOMS Incremental, Strong Constraint 4D-Var    ***"
echo "***  Master Execution Script: Sequential State Estimation  ***"
echo "**************************************************************"
echo "***"

#---------------------------------------------------------------------
#  Directories.
#---------------------------------------------------------------------

#  Set ROOT of the directory to run 4DVar.

MYROOT="/home/arango/ocean/toms/adjoint/Test/SW06c"

#  Set ROMS/TOMS ROOT directory.

ROMS_ROOT="/home/arango/ocean/toms/adjoint/src/ROMS"

#  Set storage directory for some of the relevant output NetCDF files.

STORAGE="/home/arango/ocean/toms/adjoint/Test/SW06c/Storage"

#---------------------------------------------------------------------
#  Application title and IO file prefix.
#---------------------------------------------------------------------

TITLE="ROMS/TOMS 3.0 - Shallow Water Acoustics 2006, Coarse Grid"

PREFIX="sw06c"

echo "***  $TITLE"
echo "***"
echo "   "

#---------------------------------------------------------------------
#  Input files.
#---------------------------------------------------------------------

# Set grid NetCDF file.

GRDname=${MYROOT}/Data/sw06_grid_2.nc

# Set Open boundary conditions file, if any.

BRYname=/home/wilkin/roms/sw06/in/sw06_bndy_ggg_g2v2rd.nc

# Set starting sequential assimilation first guess.

FIRST_GUESS=${MYROOT}/Data/sw06c_bck_run45.nc

# Set background-error covariance standard deviations file.

STDname=${MYROOT}/Data/sw06c_std_notide.nc

# Set background-error covariance normalization factor file

NRMname=${MYROOT}/Data/sw06c_nrm_rnd_20k5m.nc

# Set observations file.

OBSname=sw06.gliders_ssh_sst.grid_2.2.nc

#---------------------------------------------------------------------
#  Executables and standard input files
#---------------------------------------------------------------------

#  Set ROMS nonlinear and data assimilation executables.

NL_ROMS="nl_romsM"
DA_ROMS="da_romsM"

#  Set ROMS nonlinear and data assimilation standard input scripts.

NL_TEMPLATE=nl_roms.tmp
DA_TEMPLATE=da_roms.tmp

NL_STDINP=nl_roms_${PREFIX}.in
DA_STDINP=da_roms_${PREFIX}.in

#  Set ROMS Metatada variables file.

VARINFO=${MYROOT}/Data/varinfo.yaml

#  Set 4DVar input script.

I4DVAR_TEMPLATE=s4dvar.in

I4DVAR_PARAM=is4dvar.in

#  Set string manipulations perl script.

SUBSTITUTE=${ROMS_ROOT}/Bin/substitute

#---------------------------------------------------------------------
#  Time window to consider.
#---------------------------------------------------------------------

#  Set starting and ending year day of the sequential data assimilation.
#  (Reference time: days since 2006-01-01 00:00:00)

STR_DAY=192                # July 12, 2006 00:00:00 UTC/GMT
END_DAY=200

#  Set data assimilation cycle time window (days).

DayStep=2

#---------------------------------------------------------------------
#  Set few Parameters.
#---------------------------------------------------------------------

#  Set model parallel partition.

NtileI=2
NtileJ=2

#  Set number of parallel nodes to use, NCPUS = NtileI * NtileJ.

NCPUS=4

#  Set number of outer and inner loops.

Nouter=6
Ninner=5

#  Set number of timesteps to write RESTART file.  This is VERY
#  Important since we are using the restart file of the nonlinear
#  model run as the first guess fot the next assimilation cycle.
#  It MUST be equal to NTIMES.

NRST=480

#  Set enviromental variables to avoid running in the head node.

NO_LOCAL=1
EXCLUDE=10
export NO_LOCAL EXCLUDE

######################################################################
#  Start sequential data assimilation
######################################################################

cycle=0

DAY=$STR_DAY

#  Set starting initial conditions file name.

INIname=${PREFIX}_ini_${DAY}.nc
ITLname=${PREFIX}_itl_${DAY}.nc

while [ $DAY -le $END_DAY ]; do

  let "cycle+=1"

  echo ">>> Starting data assimilation cycle: $cycle"
  echo ">>>"

#---------------------------------------------------------------------
# Run 4DVar Algorithm.
#---------------------------------------------------------------------

  cd $MYROOT/I4DVAR

# Clean directory by removing all existing NetCDF files.

  if [ -e $ITLname ]; then
    /bin/rm -f $MYROOT/I4DVAR/*.nc
  fi
  ITLname=${PREFIX}_itl_${DAY}.nc

# Set backgound (first guess) state file.

  if [ $DAY -eq $STR_DAY ]; then
    cp -p ${FIRST_GUESS} $INIname
  else
    cp -p ${STORAGE}/$INIname .
  fi

# Set tangent linear model initial conditions file.

  cp -p ${MYROOT}/Data/${PREFIX}_ini_zero.nc $ITLname

# Get a clean copy of the observation file.  This is really
# important since this file is modified to compute the
# fractional vertical position of the observations when
# they are specified as depth in meter (negative values).

  cp -p ${MYROOT}/OBS/$OBSname .

# Modify 4DVar template input script and specify above files.

  if [ -e $I4DVAR_PARAM ]; then
    /bin/rm $I4DVAR_PARAM
  fi
  cp $I4DVAR_TEMPLATE $I4DVAR_PARAM

  $SUBSTITUTE $I4DVAR_PARAM roms_std.nc $STDname
  $SUBSTITUTE $I4DVAR_PARAM roms_nrm.nc $NRMname
  $SUBSTITUTE $I4DVAR_PARAM roms_obs.nc $OBSname
  $SUBSTITUTE $I4DVAR_PARAM roms_mod.nc ${PREFIX}_mod_${DAY}.nc

# Modify 4DVar ROMS standard input script.

  if [ -e $DA_STDINP ]; then
    /bin/rm $DA_STDINP
  fi
  cp $DA_TEMPLATE $DA_STDINP

  $SUBSTITUTE $DA_STDINP MyTITLE $TITLE
  $SUBSTITUTE $DA_STDINP varinfo.yaml $VARINFO
  $SUBSTITUTE $DA_STDINP MyNtileI $NtileI
  $SUBSTITUTE $DA_STDINP MyNtileJ $NtileJ
  $SUBSTITUTE $DA_STDINP MyNouter $Nouter
  $SUBSTITUTE $DA_STDINP MyNinner $Ninner
  $SUBSTITUTE $DA_STDINP myDSTART ${DAY}.0d0

  $SUBSTITUTE $DA_STDINP roms_grd.nc $GRDname
  $SUBSTITUTE $DA_STDINP roms_ini.nc $INIname
  $SUBSTITUTE $DA_STDINP roms_itl.nc $ITLname
  $SUBSTITUTE $DA_STDINP roms_bry.nc $BRYname
  $SUBSTITUTE $DA_STDINP roms_fwd.nc ${PREFIX}_fwd_${DAY}.nc

  $SUBSTITUTE $DA_STDINP roms_rst.nc ${PREFIX}_rst_${DAY}.nc
  $SUBSTITUTE $DA_STDINP roms_his.nc ${PREFIX}_his_${DAY}.nc
  $SUBSTITUTE $DA_STDINP roms_avg.nc ${PREFIX}_avg_${DAY}.nc
  $SUBSTITUTE $DA_STDINP roms_tlm.nc ${PREFIX}_tlm_${DAY}.nc
  $SUBSTITUTE $DA_STDINP roms_adj.nc ${PREFIX}_adj_${DAY}.nc
  $SUBSTITUTE $DA_STDINP s4dvar.in $I4DVAR_PARAM

# Run incremental 4DVar algorithm.

  echo ">>> Running I4DVAR algorithm, starting day: $DAY"

  if [ -e da_log.$DAY ]; then
    /bin/rm -f da_log.$DAY
  fi
  mpirun -np $NCPUS $DA_ROMS $DA_STDINP > da_log.$DAY

# Move estimated initial conditions, misfit, and log files to storage.

  echo ">>> Done running I4DVAR, moving initial conditions to storage"

  mv -f $INIname $STORAGE
  mv -f ${PREFIX}_mod_${DAY}.nc $STORAGE
  mv -f da_log.${DAY} $STORAGE

#---------------------------------------------------------------------
# Run Nonlinear model initialized with 4DVAR estimated initial
# conditions for the period of the assimilation time window. It
# will compute the first guess for the next assimilation cycle
#---------------------------------------------------------------------

  cd $MYROOT/Forward

# Create ROMS standard input script from template.

  if [ -e $NL_STDINP ]; then
    /bin/rm $NL_STDINP
  fi
  cp $NL_TEMPLATE $NL_STDINP

  RSTname=${PREFIX}_rst_${DAY}.nc

  $SUBSTITUTE $NL_STDINP MyTITLE $TITLE
  $SUBSTITUTE $NL_STDINP varinfo.yaml $VARINFO
  $SUBSTITUTE $NL_STDINP MyNtileI $NtileI
  $SUBSTITUTE $NL_STDINP MyNtileJ $NtileJ
  $SUBSTITUTE $NL_STDINP MyNRST $NRST
  $SUBSTITUTE $NL_STDINP myDSTART ${DAY}.0d0

  $SUBSTITUTE $NL_STDINP roms_grd.nc $GRDname
  $SUBSTITUTE $NL_STDINP roms_ini.nc $STORAGE/$INIname
  $SUBSTITUTE $NL_STDINP roms_bry.nc $BRYname

  $SUBSTITUTE $NL_STDINP roms_rst.nc $RSTname
  $SUBSTITUTE $NL_STDINP roms_his.nc ${PREFIX}_his_${DAY}.nc
  $SUBSTITUTE $NL_STDINP roms_avg.nc ${PREFIX}_avg_${DAY}.nc

# Run nonlinear ROMS.

  echo ">>> Running nonlinear model, starting day: $DAY"

  if [ -e nl_log.${DAY} ]; then
    /bin/rm -f nl_log.${DAY}
  fi
  mpirun -np $NCPUS $NL_ROMS $NL_STDINP > nl_log.${DAY}

# Move current nonlinear history and log files to storage.

   mv -f ${PREFIX}_his_${DAY}.nc ${STORAGE}
   mv -f nl_log.${DAY} $STORAGE

#---------------------------------------------------------------------
# Advance starting day for next assimilation cycle. Set new initial
# conditions file name.
#---------------------------------------------------------------------

  let "DAY+=DayStep"

  INIname=${PREFIX}_ini_${DAY}.nc

#---------------------------------------------------------------------
# Move next cycle first guess (background state) to storage. It is
# currently stored in the restart file.
#---------------------------------------------------------------------

  cd $MYROOT/Forward

  mv -f $RSTname ${STORAGE}/${INIname}

  echo "  "
  echo ">>> Finished data assimilation cycle: $cycle"

done

