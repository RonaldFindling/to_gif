#!/bin/bash

####################
# activate security
####################
OPTIND=1 
#set -o nounset #only set when programming (in release manual check if variables are set is neeed)
set -o errexit
set -o pipefail
shopt -s nullglob
#set -v #verbose

####################
# check dependecies
####################
# exiv2 gifsicle hugin imagemagick
# redirect std::out and std::err using "> '/dev/null' 2>&1 '/dev/null'" (shortform not supported everywhere is '&>')
dpkg -s exiv2 gifsicle hugin imagemagick > "/dev/null" 2>&1 && echo "All dependencies found." || echo -e "Not all dependencies found, check if the following packages are installed:\nexiv2, gifsicle, hugin, imagemagick" >&2

####################
# param parsing
####################
# Initialize our own variables:
data_dir="" #
colourspace="" #e.g. 256
remove_tmp_files=true
verbose=false
size=""
delay="30"
help_string="Usage: "`basename "$0"`" [-c colourSpaceSize] [-h] [-v] [-r] [-s relativeSize] [-d delayInhundredthSeconds] picturesAsWildcardOrList\n -c Determines the size of the colourspace, can be ommited in most cases. If needed try 256.\n -h Showing the helpstring, this is also done by default if you use the command without arguments.\n -v Make the command verbose.\n -r Don't remove temporary files, this will results in multiple intermediate files as well as the final gif.\n -s The wanted size of the new image, relative to the old size in percent.\n -d The time delay between the images in hundredths of a second." #\n The pictures used for gif creation, use wildcards to let the shell figure out how to represent them.

#checking for no options/paremter found
if (($# == 0)); then
	echo -e "${help_string}" >&2
	exit 1
fi

while getopts ":c:s:d:rvh?" opt; do #when ommiting the ARGS optstring uses $@
	case $opt in
		c)
			#used in gifsicle command
			colourspace=" --colors ${OPTARG}"
			;;
		s)
			size="-resize ${OPTARG}%"
			;;
		d)
			delay="${OPTARG}"
			;;
		r)
			remove_tmp_files=false
			;;
		v)
			verbose=true
			# how to check bool variable http://stackoverflow.com/a/21210966
			# if [[ "${bool}" == true ]]; then echo "true"; fi
			;;
		h|\?)
			echo -e "${help_string}"
			exit 0
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			exit 1
			;;
	esac
done

#echo $OPTIND
#echo $* #All the arguments on the command line. see http://www.unix.com/shell-programming-and-scripting/85063-how-print-all-argument-passed.html
#this is needed see http://stackoverflow.com/questions/23360148/how-to-handle-multiple-input-file-arguments-using-getopts
shift $(( OPTIND - 1 ))

#first image used for rotation state determination
array=( $@ )
# if no files provied this throws a unbound variable exception, because of the nounset option I can't check if the variable is set ... (I should deactivate -u for release and check here)
if [ -z "${array-}" ]; then
	echo "No images found." >&2
  exit 1
fi
first=${array[0]} 
data_dir=$(dirname ${first})"/"

if [[ "${verbose}" == true ]]
then 
	echo "in_files=${@}";
	echo "data_dir=${data_dir}";
	echo "verbose="${verbose};
	echo "remove_tmp_files=${remove_tmp_files}";
	echo "colourspace=${colourspace}";
	echo "size=${size}";
fi

####################
# change OS language to english 
# (needed for exiv2 metadate grepping)
####################
old_lang=$LANGUAGE
LANGUAGE="en_US:en"

####################
# create gif
####################
convert ${@} ${size} +repage ${data_dir}resized_%02d.jpg #+repage
align_image_stack -i -m -s 1 -a ${data_dir}aligned_ -C resized* #${@} #the rotation information gets lost here
PTblender -f -k 0 -t 0 -p ${data_dir}blended_ ${data_dir}aligned*
#convert blended_* -rotate +90 rotated_%02d.jpg
convert +repage -delay "${delay}" -loop 0 ${data_dir}blended_* ${data_dir}final.gif



tempfile="mysillytemp.txt"
final_file="final_rotated.gif"

#the && echo is needed!!! (otherwise unpredictable shit hapens), I have no idea why O__o
exiv2 -u -p a ${data_dir}${first} | grep -i orientation | awk '{FS=="\t"}{print $4"\t"$5}' > "${data_dir}${tempfile}" && echo ""
rotation_state="$(cat ${data_dir}${tempfile})"
#rotation_state=$((rotation_state+0))
rotation_param=""
#echo "rotation_state=${rotation_state}"

if [[ "${verbose}" == true ]]; then echo "rotation_state=${rotation_state}"; fi
# check the old rotation state and produce needed rotation params
# exiv rotation states: http://sylvana.net/jpegcrop/exif_orientation.html ; http://www.impulseadventure.com/photo/exif-orientation.html
# We use the 0th Row and the 0th Column values because exiv2 doesn't set the numeric Value !! e.g.: exiv2 -M "set Exif.Image.Orientation Short 1" test*
case "${rotation_state}" in
"top,	left") #1
	rotation_param="" #no rotation needed
	;;
"top,	right") #2
	rotation_param="--flip-horizontal" 
	;;
"bottom,	right") #3
	rotation_param="--rotate-180"
	;;
"bottom,	left") #4
	rotation_param="--rotate-180 --flip-horizontal"
	;;
"left,	top") #5
	rotation_param="--rotate-270 --flip-horizontal" 
	;;
"right,	top") #6
	rotation_param="--rotate-90"
	;;
"right,	bottom") #7
	rotation_param="--rotate-90 --flip-horizontal"
	;;
"left,	bottom") #8
	rotation_param="--rotate-90 --flip-horizontal --flip-vertical"
	;;
"*")
	echo "Ivalid rotation-state! rotation_state=${rotation_state} Terminating execution now." >&2
	exit 1
	;;
esac


if [[ "${verbose}" == true ]]; then echo "rotation_param=${rotation_param}"; fi

#rotate the final gif
if [[ "${verbose}" == true ]]; then echo "gifsicle ${rotation_param} ${colourspace} ${data_dir}final.gif > ${data_dir}${final_file}"; fi
gifsicle ${rotation_param} ${colourspace} ${data_dir}final.gif > ${data_dir}${final_file}

####################
# restore old OS language 
####################
LANGUAGE=$old_lang

####################
# cleanup
####################
if [[ "${remove_tmp_files}" == true ]]; then rm -f ${data_dir}aligned_*; fi
if [[ "${remove_tmp_files}" == true ]]; then rm -f ${data_dir}aligned_*; fi
if [[ "${remove_tmp_files}" == true ]]; then rm -f ${data_dir}blended_*; fi
if [[ "${remove_tmp_files}" == true ]]; then rm -f ${data_dir}resized_*; fi
if [[ "${remove_tmp_files}" == true ]]; then rm -f ${data_dir}${tempfile}; fi
if [[ "${remove_tmp_files}" == true ]]; then rm -f ${data_dir}zcom_log.txt ${data_dir}Debug.txt; fi
if [[ "${remove_tmp_files}" == true ]]; then rm -f ${data_dir}final.gif; fi

