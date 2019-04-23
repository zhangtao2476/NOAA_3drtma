#!/bin/ksh -l

# --- for debug --- #
date
export PS4=' $SECONDS + ' 
set -x

COMMAND=$1

#############################################################
# load modulefile and set up the environment for job runnning
#############################################################

MODULEFILES=${MODULEFILES:-${HOMErtma3d}/modulefiles}

if [ "${MACHINE}" = "jet" ] ; then

# loading modules in the general module file
#  (also including path definition of some common UNIX commands)

  . ${MODULEFILES}/${MACHINE}/run/modulefile.rtma3d_rt.run.${MACHINE}

# loading  Specific modules and configurations used in individual task 
#   and path to some specific command/tool used

  case "$COMMAND" in
    *LIGHTNING*|*SATELLITE*|*GSI_DIAG*)
      export TAIL=/usr/bin/tail
      ;;
    *GSI_HYB*)
      export TAIL=/usr/bin/tail
      ;;
    *POST*)
      module unload pnetcdf/1.6.1
      module load wgrib
      module load wgrib2/2.0.8
#     export WGRIB2="/home/rtrr/HRRR/exec/UPP/wgrib2"    # 2.0.7 (used in GSD rap/hrrr)
      export WGRIB2=${WGRIB2:-"wgrib"}
      export BC=/usr/bin/bc
      ;;
    *SMARTINIT*)
      export AWK="/bin/gawk --posix"
      export BC=/usr/bin/bc
      export GREP=/bin/grep
      ;;
  esac
  module list
else
  echo "launch.ksh: modulefile is not set up yet for this machine-->${MACHINE}."
  echo "Job abort!"
  exit 1
fi


############################################################
#                                                          #
#        obtain unique process id (pid)                    #
#                                                          #
############################################################
if [ "${MACHINE}" = "theia" ] || [ "${MACHINE}" = "jet" ] ; then    ### PBS job Scheduler
  case ${SCHEDULER} in
    PBS|pbs|moab*)                                    # PBS maob/torque
      export job=${job:-"${PBS_JOBNAME}"}
      export jid=`echo ${PBS_JOBID} | cut -f1 -d.`
#     export jid=`echo ${PBS_JOBID} | awk -F'.' '{print $1}'`
      export jobid=${jobid:-"${job}.${jid}"}
      export np=`cat $PBS_NODEFILE | wc -l`
      echo " number of cores : $np for job $job with id as $jobid "
      export MPIRUN="mpiexec -np $np"
      ;;
    SLURM|slum)                                       # SLURM
      module load rocoto/1.3.0-RC3
#     module load slurm/18.08.6-2p1
      module load slurm/18.08.7p1

      export PBS_JOBID=${SLURM_JOB_ID}
      export PBS_JOBNAME=${SLURM_JOB_NAME}
      export PBS_NP=${SLURM_NTASKS}
      export PBS_O_DIR=${SLURM_SUBMIT_DIR}
      export job=${job:-"${PBS_JOBNAME}"}
      export jid=`echo ${PBS_JOBID} | cut -f1 -d.`
#     export jid=`echo ${PBS_JOBID} | awk -F'.' '{print $1}'`
      export jobid=${jobid:-"${job}.${jid}"}
      echo "$0 -->  jobid=$jobid"

      cd ${SLURM_SUBMIT_DIR}
      if [ ! -d ${SLURM_SUBMIT_DIR}/log ] ; then
        mkdir -p ${SLURM_SUBMIT_DIR}/log
      fi
      slurm_hfile=${SLURM_SUBMIT_DIR}/log/hostfile.${SLURM_JOB_NAME}.${SLURM_JOB_ID}
      export PBS_NODEFILE=${SLURM_SUBMIT_DIR}/log/pbs_nodefile.${SLURM_JOB_NAME}.${SLURM_JOB_ID}
      scontrol show hostname $SLURM_NODELSIT > ${slurm_hfile}
      cp ${slurm_hfile} $HOME/TestDir/PBS_NODEFILE
      np=`cat ${slurm_hfile} | wc -l`
      echo "launch.sh: ${SLURM_JOB_NAME} np=$np (in SLURM hostname)"
      echo "launch.sh: ${SLURM_JOB_NAME} SLURM_NTASKS=${SLURM_NTASKS} "
      echo "Launch.sh: ${SLURM_JOB_NAME} SLURM_JOB_NUM_NODES=${SLURM_JOB_NUM_NODES} "
      echo "Launch.sh: ${SLURM_JOB_NAME} SLURM_TASKS_PER_NODE=${SLURM_TASKS_PER_NODE} "
      echo "Launch.sh: ${SLURM_JOB_NAME} SLURM_JOB_NODELIST=$SLURM_JOB_NODELIST "
      rm -f ${PBS_NODEFILE}
      i=0
      imax=${SLURM_NTASKS}
      while [[ $i -lt ${SLURM_NTASKS} ]]
      do
        cat >> ${PBS_NODEFILE} << EOF
ujet$i
EOF
        (( i += 1 ))
      done
      cp -p ${PBS_NODEFILE} $HOME/TestDir/PBS_NODEFILE
      np=`cat $PBS_NODEFILE | wc -l`
      echo "Launch.sh: ${SLURM_JOB_NAME} np=$np (in $PBS_NODEFILE)"
#     export MPIRUN="srun -n ${np}"
      export MPIRUN="srun"
      ;;
    *)
      echo "unknown scheduler: ${SCHEDULER}. $0 abort! "
      exit 1
      ;;
  esac
fi

############################################################
#                                                          #
#    define the name of running directory with job name.   #
#        (NCO: only data.${jobid})                         #
#                                                          #
############################################################
if [ -n ${rundir_task} ] ; then
  export DATA=${rundir_task}.${jid}
fi

$COMMAND
