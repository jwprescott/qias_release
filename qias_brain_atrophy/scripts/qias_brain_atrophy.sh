#!/bin/bash
# DEPENDENCIES (for Ubuntu 18.04)
#   freesurfer (>= 6.0)
#   dcmtk: sudo apt install dcmtk
#   python (>= 3.0)
#       numpy
#       itk
#   latex, pdflatex: sudo apt-get install texlive

# DEBUG INPUTS
# ./qias_brain_atrophy.sh --inputdir /home/ubuntu/Desktop/ADNI3_003_S_4119_T1 --outputdir /home/bizon/Desktop/qias_brain_atrophy_test
# ./qias_brain_atrophy.sh --inputdir /home/ubuntu/Desktop/ADNI3_003_S_4119_T1 --outputdir /home/bizon/Desktop/qias_brain_atrophy_test --no-run-seg

inputargs=("$@")
numargs=$#
DateStr="`date '+%y%m%d%H%M'`"

# Location of this script
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# qias_brain_atrophy project root
project_root_dir=${script_dir}/..

inputdir=()
outputdir=()
flag_log=()
flag_no_run_seg=()
flag_seg_ss_ax=()
flag_seg_ss_sag=()
flag_seg_ss_cor=()
flag_help=()
files=()

series_date=()
acc_num=()
modality=()
ref_phys=()
pt_name=()
pt_id=()
pt_birthdate=()
pt_sex=()
pt_age=()
echo_time=()
study_uid=()
series_uid=()

usage_exit () {
    echo ""
    echo "USAGE: qias_brain_atrophy"
    echo ""
    echo "  -i,--inputdir   : Directory containing all MR images from T1 series"
    echo "  -o,--outputdir  : Output directory for report and intermediate files"
    echo "  -l,--log        : Send command line output to logfile"
    echo "                    (default: qias_brain_atrophy.{DATE}.{PID}.log"
    echo "    ,--no-run-seg : Do not run segmentation"
    echo "    ,--seg-ss-ax  : Take axial screenshots of segmentation overlaid on T1."
    echo "                    This creates both JPEG and DICOM images, in separate"
    echo "                    directories."
    echo "    ,--seg-ss-cor : Take coronal screenshots of segmentation overlaid on T1"
    echo "                    This creates both JPEG and DICOM images, in separate"
    echo "                    directories."
    echo "    ,--seg-ss-sag : Take sagittal screenshots of segmentation overlaid on T1"
    echo "                    This creates both JPEG and DICOM images, in separate"
    echo "                    directories."
    echo "  -h,--help       : Print program help"
    echo ""
    
    exit
}

# TODO: implement function
print_help () {
    usage_exit
}

if [ $# == 0 ]; then
    usage_exit
fi

# PARSE ARGS
while (( "$#" ));
do
       
    arg=$1
    
    case $arg in
    
        "-i" | "--inputdir")            
            inputdir=$2
            shift
            ;;            
        "-o" | "--outputdir")
            outputdir=$2
            shift
            ;;
        "-l" | "--log")
            flag_log=1
            ;;
        "-h" | "--help")
            flag_help=1
            ;;
        "--no-run-seg")
            flag_no_run_seg=1
            ;;
        "--seg-ss-ax")
            flag_seg_ss_ax=1
            ;;
        "--seg-ss-cor")
            flag_seg_ss_cor=1
            ;;
        "--seg-ss-sag")
            flag_seg_ss_sag=1
            ;;
        *)
            echo "Unknown option: ${arg}"
            exit
            ;;
        esac
    
    shift
done

if [ ${flag_help} ]; then
    print_help
fi

# CHECK PARAMETERS
if [ ${#inputdir} == 0 ]; then
    echo "ERROR: you must specify an input directory"
    exit 1
fi

if [ ${#outputdir} == 0 ]; then
    echo "ERROR: you must specify an output directory"    
    exit 1
fi

if [ ${flag_log} ]; then
    # Setup log file
    date1=`date -dnow +%Y%m%d%H%M%S`
    pid1=$$
    exec 3>&1 4>&2
    trap 'exec 2>&4 1>&3' 0 1 2 3 RETURN
    echo "Successful study storage in directory ${data_dir}"
    echo "Starting qias_brain_atrophy for atrophy report creation"
    echo "Log will be saved to /tmp/qias_brain_atrophy.$date1.$pid1.log,"
    echo "then moved to output directory on completion"
    # save log file with datetime and pid identifiers
    exec 1>/tmp/qias_brain_atrophy.$date1.$pid1.log 2>&1
    # Everything below will go to the log file
fi
    
# Get T1 files, parse headers for patient info
files=(`ls ${inputdir}`)
f=${inputdir}/${files[0]}

series_date=`dcmdump --search "0008,0021" ${f} | awk -F'[\[\]]' '{print $2}'`
acc_num=`dcmdump --search "0008,0050" ${f} | awk -F'[\[\]]' '{print $2}'`
modality=`dcmdump --search "0008,0060" ${f} | awk -F'[\[\]]' '{print $2}'`
ref_phys=`dcmdump --search "0008,0090" ${f} | awk -F'[\[\]]' '{print $2}'`
pt_name=`dcmdump --search "0010,0010" ${f} | awk -F'[\[\]]' '{print $2}'`
pt_id=`dcmdump --search "0010,0020" ${f} | awk -F'[\[\]]' '{print $2}'`
pt_birthdate=`dcmdump --search "0010,0030" ${f} | awk -F'[\[\]]' '{print $2}'`
pt_sex=`dcmdump --search "0010,0040" ${f} | awk -F'[\[\]]' '{print $2}'`
pt_age=`dcmdump --search "0010,1010" ${f} | awk -F'[\[\]]' '{print $2}'`
echo_time=`dcmdump --search "0018,0081" ${f} | awk -F'[\[\]]' '{print $2}'`
study_uid=`dcmdump --search "0020,000D" ${f} | awk -F'[\[\]]' '{print $2}'`
series_uid=`dcmdump --search "0020,000E" ${f} | awk -F'[\[\]]' '{print $2}'`

age_val=${pt_age::3}
age_unit=${pt_age:3}
pt_age=()

# echo "Age value: ${age_val}"
# echo "Age unit: ${age_unit}"

if [ ${age_unit} != "Y" ]; then
    echo "ERROR: currently only age units in years is supported"
    exit 1
fi

pt_age=${age_val}
pt_age=$(echo $pt_age | sed 's/^0*//')  #remove leading zeros

# Not all DICOM headers contain patient age element.
if [ ! ${pt_age} ]; then
    # Try to calculate patient age in years from birthdate and series date. 
    pt_age=`python -c "from datetime import date, datetime; seriesdate=datetime.strptime('${series_date}','%Y%m%d'); birthdate=datetime.strptime('${pt_birthdate}','%Y%m%d'); age=seriesdate.year-birthdate.year-((seriesdate.month,seriesdate.day) < (birthdate.month,birthdate.day)); print(age)"`
fi

if [ ! ${pt_age} ]; then
    echo "ERROR: Patient age was not found in DICOM header and could not be"
    echo "calculated from other header elements."
    exit 1
fi

if [ ${pt_age} -lt 55 ] || [ ${pt_age} -gt 90 ]; then
  echo "ERROR: Patient age is outside of range for analysis (must be >= 55 and <= 90)"
  echo "Patient age = ${pt_age}"
  exit
fi

echo ""
echo "=========================="
echo "Study information"
echo "=========================="
echo "Series date: ${series_date}"
echo "Accession number: ${acc_num}"
echo "Modality: ${modality}"
echo "Referring physician: ${ref_phys}"
echo "Patient name: ${pt_name}"
echo "Patient ID: ${pt_id}"
echo "Patient sex: ${pt_sex}"
echo "Patient age: ${pt_age}"
echo "Echo time: ${echo_time}"
echo "Study instance UID: ${study_uid}"
echo "Series instance UID: ${series_uid}"



echo ""
echo "=========================="
echo "Initialize analysis"
echo "=========================="

subject=${pt_id}_${series_date}

subject_dir=${outputdir}/${subject}
report_dir=${outputdir}/${subject}/report

if [ ! -e ${subject_dir} ]; then
  echo "Creating analysis directory: ${subject_dir}"
  mkdir -p ${subject_dir}
  mkdir -p ${report_dir}
# else
# #   echo "Analysis directory already exists: ${subject_dir}"
# #   echo "Manually move or remove directory if want to rerun analysis"
# #   echo "Exiting"
# #   exit
fi

    # Setup FreeSurfer stuff
SUBJECTS_DIR=${subject_dir}/SEG
aseg_stats_file=${SUBJECTS_DIR}/${subject}/stats/aseg_qias.stats
echo "Modified ASeg stats file will be written to ${aseg_stats_file}"

if [ ! ${flag_no_run_seg} ]; then

    echo ""
    echo "=========================="
    echo "Segmentation"
    echo "=========================="
    echo ""

    echo "Convert data, save in output directory"
    mri_convert ${f} ${subject_dir}/t1.nii.gz
    
    echo "Creating FreeSurfer subject directory: ${subject_dir}/SEG"
    mkdir ${SUBJECTS_DIR}
    

    
    
    recon-all -subject ${subject} -i ${subject_dir}/t1.nii.gz -motioncor -nuintensitycor -talairach -normalization -skullstrip -gcareg -canorm -careg -parallel
    
    # for some reason aseg.mgz isn't found correctly if include calabel step in above recon-all call.
    recon-all -subject ${subject} -calabel -no-isrunning -parallel
    
    mri_segstats --seg ${SUBJECTS_DIR}/${subject}/mri/aseg.presurf.mgz --ctab $FREESURFER_HOME/ASegStatsLUT.txt --excludeid 0 --etiv --subject ${subject} --sum ${aseg_stats_file}
    
    # To allow easier use with ITK python package (which doesn't have MGHIO file reader 
    # included as part of default build)
    # There also appears to be some bug with Freeview incorrectly reading orig.nii.gz. 
    # So use uncompressed nii files
    mri_convert ${SUBJECTS_DIR}/${subject}/mri/orig.mgz ${SUBJECTS_DIR}/${subject}/mri/orig.nii
    mri_convert ${SUBJECTS_DIR}/${subject}/mri/aseg.presurf.mgz ${SUBJECTS_DIR}/${subject}/mri/aseg.presurf.nii
    
fi

echo ""
echo "=========================="
echo "Calculate segmentation statistics"
echo "=========================="

# Check that ${aseg_stats_file} exists
if [ ! -e ${aseg_stats_file} ]; then
  echo "ERROR: ${aseg_stats_file} does not exist. Did Freesurfer"
  echo "segmentation complete without error?"  
  exit 1
fi

# Extract, calculate segmented volumes
left_hipp_vol_mm3=$(grep -w "Left-Hippocampus" ${aseg_stats_file} | awk '{print $4;}')
right_hipp_vol_mm3=$(grep -w "Right-Hippocampus" ${aseg_stats_file} | awk '{print $4;}')
left_lat_vent_vol_mm3=$(grep -w "Left-Lateral-Ventricle" ${aseg_stats_file} | awk '{print $4;}')
right_lat_vent_vol_mm3=$(grep -w "Right-Lateral-Ventricle" ${aseg_stats_file} | awk '{print $4;}')
left_inf_lat_vent_vol_mm3=$(grep -w "Left-Inf-Lat-Vent" ${aseg_stats_file} | awk '{print $4;}')
right_inf_lat_vent_vol_mm3=$(grep -w "Right-Inf-Lat-Vent" ${aseg_stats_file} | awk '{print $4;}')
tot_icv=$(grep -w "EstimatedTotalIntraCranialVol" ${aseg_stats_file} | awk -F"[, ]" '{print $12;}')

left_hipp_vol_cm3=$(bc -l <<< "scale=2;$left_hipp_vol_mm3/1000")
right_hipp_vol_cm3=$(bc -l <<< "scale=2;$right_hipp_vol_mm3/1000")
left_lat_vent_vol_cm3=$(bc -l <<< "scale=2;$left_lat_vent_vol_mm3/1000")
right_lat_vent_vol_cm3=$(bc -l <<< "scale=2;$right_lat_vent_vol_mm3/1000")
left_inf_lat_vent_vol_cm3=$(bc -l <<< "scale=2;$left_inf_lat_vent_vol_mm3/1000")
right_inf_lat_vent_vol_cm3=$(bc -l <<< "scale=2;$right_inf_lat_vent_vol_mm3/1000")

left_hoc=$(bc -l <<< "scale=2;$left_hipp_vol_mm3/($left_hipp_vol_mm3+$left_inf_lat_vent_vol_mm3)")
right_hoc=$(bc -l <<< "scale=2;$right_hipp_vol_mm3/($right_hipp_vol_mm3+$right_inf_lat_vent_vol_mm3)")
mean_hoc=$(bc -l <<< "scale=2;($left_hoc+$right_hoc)/2")

tot_hipp_vol_mm3=$(bc -l <<< "scale=2;$left_hipp_vol_mm3+$right_hipp_vol_mm3")
tot_hipp_vol_cm3=$(bc -l <<< "scale=2;$tot_hipp_vol_mm3/1000")

tot_lat_vent_vol_mm3=$(bc -l <<< "scale=2;$left_lat_vent_vol_mm3+$right_lat_vent_vol_mm3")
tot_lat_vent_vol_cm3=$(bc -l <<< "scale=2;$tot_lat_vent_vol_mm3/1000")

tot_inf_lat_vent_vol_mm3=$(bc -l <<< "scale=2;$left_inf_lat_vent_vol_mm3+$right_inf_lat_vent_vol_mm3")
tot_inf_lat_vent_vol_cm3=$(bc -l <<< "scale=2;$tot_inf_lat_vent_vol_mm3/1000")

tmp=$(bc -l <<< "$tot_hipp_vol_mm3/$tot_icv*100")
tot_hipp_vol_perc_icv=$(bc -l <<< "scale=2;$tmp/1")

tmp=$(bc -l <<< "$tot_lat_vent_vol_mm3/$tot_icv*100")
tot_lat_vent_vol_perc_icv=$(bc -l <<< "scale=2;$tmp/1")

tmp=$(bc -l <<< "$tot_inf_lat_vent_vol_mm3/$tot_icv*100")
tot_inf_lat_vent_vol_perc_icv=$(bc -l <<< "scale=2;$tmp/1")

echo ""
echo "Total intracranial volume (mm3): ${tot_icv}"
echo ""
echo "Left hippocampal volume (cm3): ${left_hipp_vol_cm3}"
echo "Right hippocampal volume (cm3): ${right_hipp_vol_cm3}"
echo "Total hippocampal volume (cm3): ${tot_hipp_vol_cm3}"
echo "Total hippocampal volume, % total ICV: ${tot_hipp_vol_perc_icv}"
echo ""
echo "Left lateral ventricle volume (cm3): ${left_lat_vent_vol_cm3}"
echo "Right lateral ventricle volume (cm3): ${right_lat_vent_vol_cm3}"
echo "Total lateral ventricle volume (cm3): ${tot_lat_vent_vol_cm3}"
echo "Total lateral ventricle volume, % total ICV: ${tot_lat_vent_vol_perc_icv}"
echo ""
echo "Left inferior lateral ventricle volume (cm3): ${left_inf_lat_vent_vol_cm3}"
echo "Right inferior lateral ventricle volume (cm3): ${right_inf_lat_vent_vol_cm3}"
echo "Total inferior lateral ventricle volume (cm3): ${tot_inf_lat_vent_vol_cm3}"
echo "Total inferior lateral ventricle volume, % total ICV: ${tot_inf_lat_vent_vol_perc_icv}"
echo ""
echo "Mean hippocampal occupancy score: ${mean_hoc}"
echo ""


echo ""
echo "=========================="
echo "Create report"
echo "=========================="
echo ""

pt_sex_long=()
if [ pt_sex == "M" ]; then
    pt_sex_long="male"
else
    pt_sex_long="female"
fi

model_dir=${project_root_dir}/analysis/stats
model_file_name=qias.brain.atrophy.models.adni2_adni3.20220605.rda
hipp_gamlss_model_name=fit.gamlss.hippo_vol_perc_icv.${pt_sex_long}
lat_vent_gamlss_model_name=fit.gamlss.lat_vent_perc_icv.${pt_sex_long}
inf_lat_vent_gamlss_model_name=fit.gamlss.inf_lat_vent_perc_icv.${pt_sex_long}
mean_hoc_gamlss_model_name=fit.gamlss.mean_hoc.${pt_sex_long}

echo ""
echo "Statistical model file: ${model_dir}/${model_file_name}"
echo "Hippocampal model: ${hipp_gamlss_model_name}"
echo "Lateral ventricle model: ${lat_vent_gamlss_model_name}"
echo "Inferior lateral ventricle model: ${inf_lat_vent_gamlss_model_name}"
echo "Mean hippocampal occupancy score model: ${mean_hoc_gamlss_model_name}"

echo ""
echo "---------------------"
echo "Create age-matched reference charts, calculate normative percentiles"
echo ""

# Calculate Normative Percentiles and Create Age-Matched Reference Charts
cp ${script_dir}/qias_brain_atrophy_create_individual_atrophy_plot_template.R ${report_dir}

sed -e 's@SUBJECT_@'${subject}'@g' \
  -e 's@WORKING_DIR_@'${report_dir}'@g' \
  -e 's@MODEL_DIR_@'${model_dir}'@g' \
  -e 's@MODEL_FILE_NAME@'${model_file_name}'@g' \
  -e 's@HIPP_MODEL_NAME@'${hipp_model_name}'@g' \
  -e 's@HIPP_MODEL_STD@'${hipp_model_std}'@g' \
  -e 's@HIPP_RQ_MODEL_NAME@'${hipp_rq_model_name}'@g' \
  -e 's@HIPP_GAMLSS_MODEL_NAME@'${hipp_gamlss_model_name}'@g' \
  -e 's@LAT_VENT_GAMLSS_MODEL_NAME@'${lat_vent_gamlss_model_name}'@g' \
  -e 's@INF_LATERAL_VENT_MODEL_NAME@'${inf_lat_vent_model_name}'@g' \
  -e 's@INF_LATERAL_VENT_MODEL_STD@'${inf_lat_vent_model_std}'@g' \
  -e 's@INF_LATERAL_VENT_GAMLSS_MODEL_NAME@'${inf_lat_vent_gamlss_model_name}'@g' \
  -e 's@MEAN_HOC_GAMLSS_MODEL_NAME@'${mean_hoc_gamlss_model_name}'@g' \
  -e 's@AgeVar@'${pt_age}'@g' \
  -e 's@HippPercICVVar@'${tot_hipp_vol_perc_icv}'@g' \
  -e 's@LatVentPercICVVar@'${tot_lat_vent_vol_perc_icv}'@g' \
  -e 's@InfLateralVentPercICVVar@'${tot_inf_lat_vent_vol_perc_icv}'@g' \
  -e 's@MeanHOCVar@'${mean_hoc}'@g' \
  < ${report_dir}/qias_brain_atrophy_create_individual_atrophy_plot_template.R \
  > ${report_dir}/qias_brain_atrophy_create_individual_atrophy_plot.R

rm ${report_dir}/qias_brain_atrophy_create_individual_atrophy_plot_template.R

cmd=(Rscript ${report_dir}/qias_brain_atrophy_create_individual_atrophy_plot.R)
echo "${cmd[@]}"
eval "${cmd[@]}"

# Extract calculated normative percentiles from file
tot_hipp_norm_perc=$(grep -w "HippNormPerc" "${report_dir}/norm_percentiles.txt" | awk '{print $2;}')
tot_hipp_5th_perc=$(grep -w "Hipp5thPerc" "${report_dir}/norm_percentiles.txt" | awk '{print $2;}')
tot_hipp_95th_perc=$(grep -w "Hipp95thPerc" "${report_dir}/norm_percentiles.txt" | awk '{print $2;}')
tot_lat_vent_norm_perc=$(grep -w "LatVentNormPerc" "${report_dir}/norm_percentiles.txt" | awk '{print $2;}')
tot_lat_vent_5th_perc=$(grep -w "LatVent5thPerc" "${report_dir}/norm_percentiles.txt" | awk '{print $2;}')
tot_lat_vent_95th_perc=$(grep -w "LatVent95thPerc" "${report_dir}/norm_percentiles.txt" | awk '{print $2;}')
tot_inf_lat_vent_norm_perc=$(grep -w "InfLateralVentNormPerc" "${report_dir}/norm_percentiles.txt" | awk '{print $2;}')
tot_inf_lat_vent_5th_perc=$(grep -w "InfLateralVent5thPerc" "${report_dir}/norm_percentiles.txt" | awk '{print $2;}')
tot_inf_lat_vent_95th_perc=$(grep -w "InfLateralVent95thPerc" "${report_dir}/norm_percentiles.txt" | awk '{print $2;}')

echo ""
echo "L+R hippocampus, normative percentile (5th, 95th): ${tot_hipp_norm_perc}, (${tot_hipp_5th_perc}, ${tot_hipp_95th_perc})"
echo "L+R lateral ventricles, normative percentile (5th, 95th): ${tot_lat_vent_norm_perc}, (${tot_lat_vent_5th_perc}, ${tot_lat_vent_95th_perc})"
echo "L+R inferior lateral ventricles, normative percentile (5th, 95th): ${tot_inf_lat_vent_norm_perc}, (${tot_inf_lat_vent_5th_perc}, ${tot_inf_lat_vent_95th_perc})"

echo ""
echo "---------------------"
echo "Take screenshots of segmentation"
echo ""

echo "Calculate centroids of hippocampi"

cp ${script_dir}/qias_brain_atrophy_aseg_hippo_centroids_template.py ${report_dir}

sed -e 's@ASEG_FILE@'${SUBJECTS_DIR}/${subject}/mri/aseg.presurf.nii'@g' \
  -e 's@OUTPUT_FILE@'${report_dir}/centroids.txt'@g' \
  < ${report_dir}/qias_brain_atrophy_aseg_hippo_centroids_template.py \
  > ${report_dir}/qias_brain_atrophy_aseg_hippo_centroids.py
  
rm ${report_dir}/qias_brain_atrophy_aseg_hippo_centroids_template.py

cmd=(python ${report_dir}/qias_brain_atrophy_aseg_hippo_centroids.py)
echo "${cmd[@]}"
eval "${cmd[@]}"
echo ""

right_hippo_centroid_x=$(grep -w "RightHippocampus" "${report_dir}/centroids.txt" | awk '{print $2;}')
right_hippo_centroid_y=$(grep -w "RightHippocampus" "${report_dir}/centroids.txt" | awk '{print $3;}')
right_hippo_centroid_z=$(grep -w "RightHippocampus" "${report_dir}/centroids.txt" | awk '{print $4;}')
left_hippo_centroid_x=$(grep -w "LeftHippocampus" "${report_dir}/centroids.txt" | awk '{print $2;}')
left_hippo_centroid_y=$(grep -w "LeftHippocampus" "${report_dir}/centroids.txt" | awk '{print $3;}')
left_hippo_centroid_z=$(grep -w "LeftHippocampus" "${report_dir}/centroids.txt" | awk '{print $4;}')

echo "Right hippocampus centroid (x,y,z): ${right_hippo_centroid_x}, ${right_hippo_centroid_y}, ${right_hippo_centroid_z}"
echo "Left hippocampus centroid (x,y,z): ${left_hippo_centroid_x}, ${left_hippo_centroid_y}, ${left_hippo_centroid_z}"
echo ""

echo "Take screenshots centered at right hippocampus"

# Freesurfer v6.0.0
cmd=(freeview -v ${SUBJECTS_DIR}/${subject}/mri/orig.nii -v ${SUBJECTS_DIR}/${subject}/mri/aseg.presurf.nii:colormap=lut:opacity=0.2 --viewport axial --camera zoom 1.0 --slice ${right_hippo_centroid_x} ${right_hippo_centroid_y} ${right_hippo_centroid_z} --viewsize 512 512 --screenshot ${report_dir}/axial.png)
echo "${cmd[@]}"
eval "${cmd[@]}"
echo ""
cmd=(freeview -v ${SUBJECTS_DIR}/${subject}/mri/orig.nii -v ${SUBJECTS_DIR}/${subject}/mri/aseg.presurf.nii:colormap=lut:opacity=0.2 --viewport coronal --camera zoom 1.0 --slice ${right_hippo_centroid_x} ${right_hippo_centroid_y} ${right_hippo_centroid_z} --viewsize 512 512 --screenshot ${report_dir}/coronal.png)
echo "${cmd[@]}"
eval "${cmd[@]}"
echo ""
cmd=(freeview -v ${SUBJECTS_DIR}/${subject}/mri/orig.nii -v ${SUBJECTS_DIR}/${subject}/mri/aseg.presurf.nii:colormap=lut:opacity=0.2 --viewport sagittal --camera zoom 1.0 --slice ${right_hippo_centroid_x} ${right_hippo_centroid_y} ${right_hippo_centroid_z} --viewsize 512 512 --screenshot ${report_dir}/sagittal.png)
echo "${cmd[@]}"
eval "${cmd[@]}"
echo ""

echo ""
echo "---------------------"
echo "Compile final report"
echo ""

cp ${script_dir}/qias_brain_atrophy_report_template.tex ${report_dir}

# Prepend special latex characters with escape character or remove character
pt_id_esc="${pt_id//_/\\\\_}"
pt_name_esc="${pt_name//_/\\\\_}"
pt_name_esc="${pt_name_esc// /,}"
pt_name_esc="${pt_name_esc//^^/}"
pt_name_esc="${pt_name_esc//^/,}"
acc_num_esc="${acc_num//_/\\\\_}"
ref_phys_esc="${ref_phys//_/\\\\_}"
ref_phys_esc="${ref_phys_esc// /,}"
ref_phys_esc="${ref_phys_esc//^^/}"
ref_phys_esc="${ref_phys_esc//^/,}"

# If critical values for normative percentiles, make text red
if [ ${tot_hipp_norm_perc} -le 5 ]; then
    tot_hipp_norm_perc="\\\textcolor\{red\}\{${tot_hipp_norm_perc}\}"
fi
if [ ${tot_lat_vent_norm_perc} -ge 95 ]; then
    tot_lat_vent_norm_perc="\\\textcolor\{red\}\{${tot_lat_vent_norm_perc}\}"
fi
if [ ${tot_inf_lat_vent_norm_perc} -ge 95 ]; then
    tot_inf_lat_vent_norm_perc="\\\textcolor\{red\}\{${tot_inf_lat_vent_norm_perc}\}"
fi

echo "Critical values for normative percentiles"
echo "Hippocampus: ${tot_hipp_norm_perc}"
echo "Lateral ventricle: ${tot_lat_vent_norm_perc}"
echo "Inferior lateral ventricle ${tot_inf_lat_vent_norm_perc}"

sed -e 's@SUBJECT_@'${subject}'@g' \
  -e 's@PtIDVar@'${pt_id_esc}'@g' \
  -e 's@PtNameVar@'${pt_name_esc}'@g' \
  -e 's@AgeVar@'${pt_age}'@g' \
  -e 's@SexVar@'${pt_sex}'@g' \
  -e 's@AccNumVar@'${acc_num_esc}'@g' \
  -e 's@RefVar@'${ref_phys_esc}'@g' \
  -e 's@ExamDateVar@'${series_date}'@g' \
  -e 's@,bb = 0 0 200 100, draft, type=eps@''@g' \
  -e 's@HippVolVar@'${tot_hipp_vol_cm3}'@g' \
  -e 's@HippPercICVVar@'${tot_hipp_vol_perc_icv}'@g' \
  -e 's@Hipp5thPercVar@'${tot_hipp_5th_perc}'@g' \
  -e 's@Hipp95thPercVar@'${tot_hipp_95th_perc}'@g' \
  -e 's@HippNormPercVar@'${tot_hipp_norm_perc}'@g' \
  -e 's@LatVentVolVar@'${tot_lat_vent_vol_cm3}'@g' \
  -e 's@LatVentPercICVVar@'${tot_lat_vent_vol_perc_icv}'@g' \
  -e 's@LatVent5thPercVar@'${tot_lat_vent_5th_perc}'@g' \
  -e 's@LatVent95thPercVar@'${tot_lat_vent_95th_perc}'@g' \
  -e 's@LatVentNormPercVar@'${tot_lat_vent_norm_perc}'@g' \
  -e 's@InfLateralVentVolVar@'${tot_inf_lat_vent_vol_cm3}'@g' \
  -e 's@InfLateralVentPercICVVar@'${tot_inf_lat_vent_vol_perc_icv}'@g' \
  -e 's@InfLateralVent5thPercVar@'${tot_inf_lat_vent_5th_perc}'@g' \
  -e 's@InfLateralVent95thPercVar@'${tot_inf_lat_vent_95th_perc}'@g' \
  -e 's@InfLateralVentNormPercVar@'${tot_inf_lat_vent_norm_perc}'@g' \
  -e 's@MeanHOCVar@'${mean_hoc}'@g' \
  -e 's@HippAtrophyAxialImg@'${report_dir}/axial'@g' \
  -e 's@HippAtrophyCoronalImg@'${report_dir}/coronal'@g' \
  -e 's@HippAtrophySagittalImg@'${report_dir}/sagittal'@g' \
  -e 's@HippAtrophyPlot@'${report_dir}/hipp_atrophy_plot'@g' \
  -e 's@InfLateralVentPlot@'${report_dir}/inf_lat_vent_plot'@g' \
  -e 's@MeanHOCPlot@'${report_dir}/mean_hoc_plot'@g' \
  < ${report_dir}/qias_brain_atrophy_report_template.tex \
  > ${report_dir}/qias_brain_atrophy_report.tex

rm ${report_dir}/qias_brain_atrophy_report_template.tex

cmd=(pdflatex -output-directory=${report_dir} ${report_dir}/qias_brain_atrophy_report.tex)
echo "${cmd[@]}"
eval "${cmd[@]}"

if [[ ${flag_seg_ss_ax} || ${flag_seg_ss_cor} || ${flag_seg_ss_sag} ]]; then

    echo ""
    echo "---------------------"
    echo "Take screenshots of all slices in desired planes"
    echo ""

    # output directories
    if [ ${flag_seg_ss_ax} ]; then
        mkdir ${report_dir}/axial
        mkdir ${report_dir}/axial_dcm
    fi
    if [ ${flag_seg_ss_cor} ]; then
        mkdir ${report_dir}/coronal
        mkdir ${report_dir}/coronal_dcm
        
    fi
    if [ ${flag_seg_ss_sag} ]; then
        mkdir ${report_dir}/sagittal
        mkdir ${report_dir}/sagittal_dcm
    fi

    cp ${script_dir}/cmd_screenshot_x_plane_template.txt ${report_dir}
    cp ${script_dir}/cmd_screenshot_y_plane_template.txt ${report_dir}
    cp ${script_dir}/cmd_screenshot_z_plane_template.txt ${report_dir}

    primary_axis=`mri_info ${SUBJECTS_DIR}/${subject}/mri/orig.nii | grep 'Primary Slice Direction' | awk '{print $4;}'`

    # TODO: what if primary axis is oblique? Does freesurfer automatically reslice
    # input image to coronal primary axis and save as orig.mgz?
    # https://surfer.nmr.mgh.harvard.edu/pub/docs/html/mri_convert.help.xml.html

    # TODO: note that following code may not work appropriately; may want to just reorient
    # with ITK


    if [ "${primary_axis}" == "axial" ]; then

        sed -e 's@ORIG_FILE@'${SUBJECTS_DIR}/${subject}/mri/orig.nii'@g' \
        -e 's@ASEG_FILE@'${SUBJECTS_DIR}/${subject}/mri/aseg.presurf.nii'@g' \
        -e 's@X_PLANE@'sagittal'@g' \
        -e 's@REPORT_DIR@'${report_dir}'@g' \
        < ${report_dir}/cmd_screenshot_x_plane_template.txt \
        > ${report_dir}/cmd_screenshot_x_plane.txt
        
        sed -e 's@ORIG_FILE@'${SUBJECTS_DIR}/${subject}/mri/orig.nii'@g' \
        -e 's@ASEG_FILE@'${SUBJECTS_DIR}/${subject}/mri/aseg.presurf.nii'@g' \
        -e 's@Y_PLANE@'coronal'@g' \
        -e 's@REPORT_DIR@'${report_dir}'@g' \
        < ${report_dir}/cmd_screenshot_y_plane_template.txt \
        > ${report_dir}/cmd_screenshot_y_plane.txt
        
        sed -e 's@ORIG_FILE@'${SUBJECTS_DIR}/${subject}/mri/orig.nii'@g' \
        -e 's@ASEG_FILE@'${SUBJECTS_DIR}/${subject}/mri/aseg.presurf.nii'@g' \
        -e 's@Z_PLANE@'axial'@g' \
        -e 's@REPORT_DIR@'${report_dir}'@g' \
        < ${report_dir}/cmd_screenshot_z_plane_template.txt \
        > ${report_dir}/cmd_screenshot_z_plane.txt
        
    elif [ "${primary_axis}" == "coronal" ]; then

        sed -e 's@ORIG_FILE@'${SUBJECTS_DIR}/${subject}/mri/orig.nii'@g' \
        -e 's@ASEG_FILE@'${SUBJECTS_DIR}/${subject}/mri/aseg.presurf.nii'@g' \
        -e 's@X_PLANE@'sagittal'@g' \
        -e 's@REPORT_DIR@'${report_dir}'@g' \
        < ${report_dir}/cmd_screenshot_x_plane_template.txt \
        > ${report_dir}/cmd_screenshot_x_plane.txt
        
        sed -e 's@ORIG_FILE@'${SUBJECTS_DIR}/${subject}/mri/orig.nii'@g' \
        -e 's@ASEG_FILE@'${SUBJECTS_DIR}/${subject}/mri/aseg.presurf.nii'@g' \
        -e 's@Y_PLANE@'axial'@g' \
        -e 's@REPORT_DIR@'${report_dir}'@g' \
        < ${report_dir}/cmd_screenshot_y_plane_template.txt \
        > ${report_dir}/cmd_screenshot_y_plane.txt
        
        sed -e 's@ORIG_FILE@'${SUBJECTS_DIR}/${subject}/mri/orig.nii'@g' \
        -e 's@ASEG_FILE@'${SUBJECTS_DIR}/${subject}/mri/aseg.presurf.nii'@g' \
        -e 's@Z_PLANE@'coronal'@g' \
        -e 's@REPORT_DIR@'${report_dir}'@g' \
        < ${report_dir}/cmd_screenshot_z_plane_template.txt \
        > ${report_dir}/cmd_screenshot_z_plane.txt

    elif [ "${primary_axis}" == "sagittal" ]; then

        sed -e 's@ORIG_FILE@'${SUBJECTS_DIR}/${subject}/mri/orig.nii'@g' \
        -e 's@ASEG_FILE@'${SUBJECTS_DIR}/${subject}/mri/aseg.presurf.nii'@g' \
        -e 's@X_PLANE@'coronal'@g' \
        -e 's@REPORT_DIR@'${report_dir}'@g' \
        < ${report_dir}/cmd_screenshot_x_plane_template.txt \
        > ${report_dir}/cmd_screenshot_x_plane.txt
        
        sed -e 's@ORIG_FILE@'${SUBJECTS_DIR}/${subject}/mri/orig.nii'@g' \
        -e 's@ASEG_FILE@'${SUBJECTS_DIR}/${subject}/mri/aseg.presurf.nii'@g' \
        -e 's@Y_PLANE@'axial'@g' \
        -e 's@REPORT_DIR@'${report_dir}'@g' \
        < ${report_dir}/cmd_screenshot_y_plane_template.txt \
        > ${report_dir}/cmd_screenshot_y_plane.txt
        
        sed -e 's@ORIG_FILE@'${SUBJECTS_DIR}/${subject}/mri/orig.nii'@g' \
        -e 's@ASEG_FILE@'${SUBJECTS_DIR}/${subject}/mri/aseg.presurf.nii'@g' \
        -e 's@Z_PLANE@'sagittal'@g' \
        -e 's@REPORT_DIR@'${report_dir}'@g' \
        < ${report_dir}/cmd_screenshot_z_plane_template.txt \
        > ${report_dir}/cmd_screenshot_z_plane.txt

    else

        echo "Primary image axis direction is oblique"
    
    fi

    rm ${report_dir}/cmd_screenshot_x_plane_template.txt
    rm ${report_dir}/cmd_screenshot_y_plane_template.txt
    rm ${report_dir}/cmd_screenshot_z_plane_template.txt

    # Axial screenshots
    if [ ${flag_seg_ss_ax} ]; then
        echo "Axial screenshots"
        if [ "${primary_axis}" == "axial" ]; then
            cmd=(freeview -cmd ${report_dir}/cmd_screenshot_z_plane.txt)
            echo "${cmd[@]}"
            eval "${cmd[@]}"
            echo ""  
        elif [ "${primary_axis}" == "coronal" ]; then
            cmd=(freeview -cmd ${report_dir}/cmd_screenshot_y_plane.txt)
            echo "${cmd[@]}"
            eval "${cmd[@]}"
            echo ""
        elif [ "${primary_axis}" == "sagittal" ]; then
            cmd=(freeview -cmd ${report_dir}/cmd_screenshot_y_plane.txt)
            echo "${cmd[@]}"
            eval "${cmd[@]}"
            echo ""
        else
            echo "Primary image axis direction is oblique"  
            cmd=(freeview -cmd ${report_dir}/cmd_screenshot_z_plane.txt)
            echo "${cmd[@]}"
            eval "${cmd[@]}"
            echo ""  
        fi
        
        # Get study UID from original T1 image, use to create series UID 
        # to apply to all secondary captures
        axial_images=(`ls ${report_dir}/axial/*.jpg`)
        cmd=(img2dcm --study-from ${f} ${axial_images[0]} ${report_dir}/axial_dcm_tmp.dcm)
        echo "${cmd[@]}"
        eval "${cmd[@]}"
        
        for (( i = 0; i < ${#axial_images[@]} ; i = $i+1 )); do
            b=`basename ${axial_images[$i]}`
            b="${b%.*}"
            #Create dicom image
            cmd=(img2dcm --series-from ${report_dir}/axial_dcm_tmp.dcm -k \"SeriesDescription=QIAS Brain Atrophy segmentation axial\" -k \"InstanceNumber=$((i+1))\" -k \"PhotometricInterpretation=YBR_FULL_422\" ${axial_images[$i]} ${report_dir}/axial_dcm/${b}.dcm)
            echo "${cmd[@]}"
            eval "${cmd[@]}"
            #Decompress dicom image
            cmd=(dcmdjpeg ${report_dir}/axial_dcm/${b}.dcm ${report_dir}/axial_dcm/${b}.dcm)
            echo "${cmd[@]}"
            eval "${cmd[@]}"
        done
        
    fi
    
    # Coronal screenshots
    if [ ${flag_seg_ss_cor} ]; then
        echo "Coronal screenshots"
        if [ "${primary_axis}" == "axial" ]; then
            cmd=(freeview -cmd ${report_dir}/cmd_screenshot_y_plane.txt)
            echo "${cmd[@]}"
            eval "${cmd[@]}"
            echo ""  
        elif [ "${primary_axis}" == "coronal" ]; then
            cmd=(freeview -cmd ${report_dir}/cmd_screenshot_z_plane.txt)
            echo "${cmd[@]}"
            eval "${cmd[@]}"
            echo ""
        elif [ "${primary_axis}" == "sagittal" ]; then
            cmd=(freeview -cmd ${report_dir}/cmd_screenshot_x_plane.txt)
            echo "${cmd[@]}"
            eval "${cmd[@]}"
            echo ""
        else
            echo "Primary image axis direction is oblique"  
            cmd=(freeview -cmd ${report_dir}/cmd_screenshot_y_plane.txt)
            echo "${cmd[@]}"
            eval "${cmd[@]}"
            echo ""  
        fi
        
        # Get study UID from original T1 image, use to create series UID 
        # to apply to all secondary captures
        coronal_images=(`ls ${report_dir}/coronal/*.jpg`)
        cmd=(img2dcm --study-from ${f} ${coronal_images[0]} ${report_dir}/coronal_dcm_tmp.dcm)
        echo "${cmd[@]}"
        eval "${cmd[@]}"
        
        for (( i = 0; i < ${#coronal_images[@]} ; i = $i+1 )); do
            b=`basename ${coronal_images[$i]}`
            b="${b%.*}"
            #Create dicom image
            cmd=(img2dcm --series-from ${report_dir}/coronal_dcm_tmp.dcm -k \"SeriesDescription=QIAS Brain Atrophy segmentation coronal\" -k \"InstanceNumber=$((i+1))\" -k \"PhotometricInterpretation=YBR_FULL_422\" ${coronal_images[$i]} ${report_dir}/coronal_dcm/${b}.dcm)
            echo "${cmd[@]}"
            eval "${cmd[@]}"
            #Decompress dicom image
            cmd=(dcmdjpeg ${report_dir}/coronal_dcm/${b}.dcm ${report_dir}/coronal_dcm/${b}.dcm)
            echo "${cmd[@]}"
            eval "${cmd[@]}"
        done
        
    fi
    
    # Sagittal screenshots
    if [ ${flag_seg_ss_sag} ]; then
        echo "Sagittal screenshots"
        if [ "${primary_axis}" == "axial" ]; then
            cmd=(freeview -cmd ${report_dir}/cmd_screenshot_x_plane.txt)
            echo "${cmd[@]}"
            eval "${cmd[@]}"
            echo ""  
        elif [ "${primary_axis}" == "coronal" ]; then
            cmd=(freeview -cmd ${report_dir}/cmd_screenshot_x_plane.txt)
            echo "${cmd[@]}"
            eval "${cmd[@]}"
            echo ""
        elif [ "${primary_axis}" == "sagittal" ]; then
            cmd=(freeview -cmd ${report_dir}/cmd_screenshot_z_plane.txt)
            echo "${cmd[@]}"
            eval "${cmd[@]}"
            echo ""
        else
            echo "Primary image axis direction is oblique"  
            cmd=(freeview -cmd ${report_dir}/cmd_screenshot_x_plane.txt)
            echo "${cmd[@]}"
            eval "${cmd[@]}"
            echo ""  
        fi
        
        # Get study UID from original T1 image, use to create series UID 
        # to apply to all secondary captures
        sagittal_images=(`ls ${report_dir}/sagittal/*.jpg`)
        cmd=(img2dcm --study-from ${f} ${sagittal_images[0]} ${report_dir}/sagittal_dcm_tmp.dcm)
        echo "${cmd[@]}"
        eval "${cmd[@]}"
        
        for (( i = 0; i < ${#sagittal_images[@]} ; i = $i+1 )); do
            b=`basename ${sagittal_images[$i]}`
            b="${b%.*}"
            #Create dicom image
            cmd=(img2dcm --series-from ${report_dir}/sagittal_dcm_tmp.dcm -k \"SeriesDescription=QIAS Brain Atrophy segmentation sagittal\" -k \"InstanceNumber=$((i+1))\" -k \"PhotometricInterpretation=YBR_FULL_422\" ${sagittal_images[$i]} ${report_dir}/sagittal_dcm/${b}.dcm)
            echo "${cmd[@]}"
            eval "${cmd[@]}"
            #Decompress dicom image
            cmd=(dcmdjpeg ${report_dir}/sagittal_dcm/${b}.dcm ${report_dir}/sagittal_dcm/${b}.dcm)
            echo "${cmd[@]}"
            eval "${cmd[@]}"
        done
        
    fi
    
fi



##########################

if [ ${flag_log} ]; then
    mv /tmp/qias_brain_atrophy.$date1.$pid1.log ${subject_dir}
fi
