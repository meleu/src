# generate-launching-images.sh
##############################
#
# This script creates launching images for a specific theme.
# If you don't know what it is, take a look at these links:
# - https://github.com/retropie/retropie-setup/wiki/runcommand#adding-custom-launching-images
# - https://retropie.org.uk/forum/topic/4611/runcommand-system-splashscreens
#
# Requirements:
# - RetroPie 4.0.3+
# - the imagemagick package installed (it means 26.1 MB of disk space used).
#
# TODO: 
# - best options for known themes
# - --logo-belt
# - --loading-text-belt
# - --press-button-text-belt
# - --es-view
# - --logo-color
# - --all-systems

# globals ###################################################################

readonly ES_DIR=("$HOME/.emulationstation" "/etc/emulationstation")
readonly CONFIGS="/opt/retropie/configs"
readonly TMP_BACKGROUND="/tmp/background.png"
readonly TMP_LOGO="/tmp/system_logo.png"
readonly TMP_LAUNCHING="/tmp/tmp_launching.png"
readonly FINAL_IMAGE="/tmp/launching"
THEME_DIR=
ES_SYSTEMS_CFG=
FAILED_SYSTEMS=()
SUCCEEDED_SYSTEMS=()

# --theme
THEME=

# --extension
EXT="png"

# --show-timeout
SHOW_TIMEOUT=5

# --no-ask
NO_ASK=0

# --loading-text
LOADING_TEXT="NOW LOADING"

# --press-button-text
PRESS_BUTTON_TEXT="PRESS A BUTTON TO CONFIGURE LAUNCH OPTIONS"

# --loading-text-color
LOADING_TEXT_COLOR="white"

# --press-button-text-color
PRESS_BUTTON_TEXT_COLOR="gray50"

# --no-logo
NO_LOGO="0"

# --all-systems
ALL_SYSTEMS="0"

# --destination-dir
DESTINATION_DIR="$CONFIGS"

# --system
SYSTEMS_ARRAY=()

# --solid-bg-color
SOLID_BG_COLOR=
SOLID_BG_COLOR_FLAG=

# --logo-belt
LOGO_BELT="0"

# --loading-text-belt
LOADING_TEXT_BELT="0"

# --press-button-text-belt
PRESS_BUTTON_TEXT_BELT="0"

# --es-view
ES_VIEW=

# --logo-color
LOGO_COLOR=

# --logo-belt-color
LOGO_BELT_COLOR=



# functions #################################################################

function safe_exit() {
    rm -f "$TMP_BACKGROUND" "$TMP_LOGO" "$TMP_LAUNCHING" "$FINAL_IMAGE.$EXT"
    exit $1
}



# checking dependencies
function check_dep() {
    # checking if we have the imagemagick installed
    if ! which convert > /dev/null; then
        echo "ERROR: The imagemagick package isn't installed!"
        echo "Please install it with 'sudo apt-get install imagemagick'."
        exit 1
    fi
    # if we are running under X we need feh
    if [[ -n "$DISPLAY" ]] && ! which feh > /dev/null; then
        echo "ERROR: The feh package isn't installed!"
        echo "Please install it with 'sudo apt-get install feh'."
        exit 1
    fi
}



function usage() {
    echo
    echo "USAGE: $(basename $0) -t theme-name [options]"
    echo
    echo "Use '--help' to see all the options"
    echo
}



function list_themes() {
    echo
    echo "Available themes on your system:"
    local dir=
    for dir in "${ES_DIR[@]}"; do
        ls -d "$dir"/themes/*/ | xargs basename -a
    done
}



function check_argument() {
    # FIXME: it'll be a problem if a theme name starts with '-'
    if [[ -z "$2" || "$2" =~ ^- ]]; then
        echo "$1: missing argument" >&2
        return 1
    fi
}



function proceed() {
    local msg=$(
        echo    "Theme......................: $THEME\n"
        echo    "Image extension............: $EXT\n"
        echo    "\"LOADING\" text.............: $LOADING_TEXT\n"
        echo    "\"PRESS A BUTTON\" text......: $PRESS_BUTTON_TEXT\n"
        echo    "\"LOADING\" text color.......: $LOADING_TEXT_COLOR\n"
        echo    "\"PRESS A BUTTON\" text color: $PRESS_BUTTON_TEXT_COLOR\n"
        echo    "Destination directory......: \"$DESTINATION_DIR\"\n"
        echo    "Show image timeout.........: $SHOW_TIMEOUT\n"

        [[ "$SOLID_BG_COLOR_FLAG" = "1" ]] \
        && echo "Solid background color.....: ${SOLID_BG_COLOR:-from the theme}\n"

        [[ "$NO_ASK" = "1" ]] \
        && echo "Do not ask for confirmation (blindly accept generated images).\n"

        [[ "$NO_LOGO" = "1" ]]  \
        && echo "The images will be created with no system logo.\n"

        echo "\n\nDO YOU WANT TO PROCEED?\n"
    )

    dialog \
      --title " SETTINGS SUMMARY " \
      --yesno "$msg" \
      20 75 || exit
}



# check if $1 is a valid color, exit if it's not.
function validate_color() {
    if convert -list color | grep -q "^$1\b"; then
        return 0
    fi
    echo "ERROR: invalid color \"$1\"." >&2
    echo "Short list of available colors:" >&2
    echo "black white gray gray10 gray25 gray50 gray75 gray90" >&2
    echo "pink red orange yellow green silver blue cyan purple brown" >&2
    echo "TIP: run the 'convert -list color' command to get a full list" >&2
    exit 1
}



# deal with command line arguments
function get_options() {
    for dir in "${ES_DIR[@]}"; do
        if [[ -f "$dir/es_systems.cfg" ]]; then
            ES_SYSTEMS_CFG="$dir/es_systems.cfg"
            break
        fi
    done
    while [[ "$1" ]]; do
        case "$1" in

#H -h, --help                   Print the help message and exit.
        -h|--help)
            usage
            # getting the help message from the comments in this source code
            sed '/^#H /!d; s/^#H //' "$0"
            exit 0
            ;;

        -v|--verbose)
            VERBOSE="1"
            ;;

#H -t, --theme THEME            Create launching images based on THEME. This is
#H                              the only mandatory option in order to generate
#H                              the images (see --list-themes).
        -t|--theme)
            check_argument "$1" "$2" || exit 1
            shift

            local dir=
            for dir in "${ES_DIR[@]}"; do
                dir="$dir/themes/$1"
                if [[ -d "$dir" ]]; then
                    THEME_DIR="$dir"
                    break
                fi
            done

            if ! [[ -d "$THEME_DIR" ]]; then
                echo "ERROR: there's no theme named \"$1\" installed." >&2
                list_themes
                exit 1
            fi
            # if reached this point, the THEME_DIR is OK
            THEME="$1"
            ;;

#H --list-themes                List the available themes and exit.
        --list-themes)
            list_themes
            exit
            ;;

#H --extension EXT              Set the extension of the created image file
#H                              (valid options: png|jpg).
        --extension)
            check_argument "$1" "$2" || exit 1
            shift
            if ! [[ "$1" =~ ^(png|jpg)$ ]]; then
                echo "ERROR: invalid extension: $1" >&2
                echo "Valid extensions: png jpg" >&2
                exit 1
            fi
            EXT="$1" 
            ;;

#H --no-ask                     Do not show the created images and ask for
#H                              confirmation (blindly accept the created images).
        --no-ask)
            NO_ASK="1"
            ;;

#H --loading-text "TEXT"        Set the "LOADING" text (default: "NOW LOADING").
        --loading-text)
            if check_argument "$1" "$2"; then
                shift
                LOADING_TEXT="$1"
            else
                LOADING_TEXT=""
            fi
            ;;

#H --press-button-text "TEXT"   Set the "PRESS A BUTTON" text (default:
#H                              "PRESS A BUTTON TO CONFIGURE LAUNCH OPTIONS").
        --press-button-text)
            if check_argument "$1" "$2"; then
                shift
                PRESS_BUTTON_TEXT="$1"
            else
                PRESS_BUTTON_TEXT=""
            fi
            ;;

#H --loading-text-color COLOR   Set the color for the "LOADING" text
#H                              (default: white).
        --loading-text-color)
            check_argument "$1" "$2" || exit 1
            shift
            validate_color "$1"
            LOADING_TEXT_COLOR="$1"
            ;;
            
#H --press-button-text-color COLOR  Set the color for the "PRESS A BUTTON" text.
#H                                  (default: gray50).
        --press-button-text-color)
            check_argument "$1" "$2" || exit 1
            shift
            validate_color "$1"
            PRESS_BUTTON_TEXT_COLOR="$1"
            ;;

#H --no-logo                    Do not put the system logo on the created image.
        --no-logo)
            NO_LOGO="1"
            ;;

#H --destination-dir DIR        Put the created images in DIR directory tree
#H                              (default: /opt/retropie/configs/).
        --destination-dir)
            check_argument "$1" "$2" || exit 1
            shift
            DESTINATION_DIR="$1"

            mkdir -p "$DESTINATION_DIR"
            if ! [[ -d "$DESTINATION_DIR" ]]; then
                echo "ERROR: failed to create \"$DESTINATION_DIR\"."
                exit 1
            fi
            ;;

#H --system SYSTEM              Create image only for SYSTEM (the default is
#H                              create for all systems found in es_systems.cfg).
        --system)
            check_argument "$1" "$2" || exit 1
            shift
            SYSTEMS_ARRAY="$1"
            ;;

#H --show-timeout TIME          Show the created image for TIME seconds before
#H                              ask if the user accept it (see --no-ask).
        --show-timeout)
            check_argument "$1" "$2" || exit 1
            shift
            SHOW_TIMEOUT=$1
            ;;

#H --solid-bg-color [COLOR]     Use a solid color as background. If COLOR is
#H                              omitted, use the color specified by the theme.
        --solid-bg-color)
            if check_argument "$1" "$2"; then
                validate_color "$2"
                SOLID_BG_COLOR="$2"
                shift
            fi
            SOLID_BG_COLOR_FLAG="1"
            ;;

        *)
            echo "ERROR: invalid option \"$1\"" >&2
            exit 2
            ;;
        esac
        shift
    done

    if [[ -z "$THEME" ]]; then
        echo "ERROR: missing theme"
        usage
        exit 1
    fi
}



function show_image() {
    [[ -f "$1" ]] || return 1

    local image="$1"

    # if we are running under X use feh otherwise try to use fbi
    # TODO: display the image until user press enter (no timeout)
    if [[ -n "$DISPLAY" ]]; then
        feh -F -N -Z -Y -q "$image" & &>/dev/null
        local pid=$!
        sleep "$SHOW_TIMEOUT"
        kill -SIGINT "$pid" 2>/dev/null
    else
        fbi -1 -t "$SHOW_TIMEOUT" -noverbose -a "$image" </dev/tty &>/dev/null
    fi
}



function get_systems() {
    # if user explicitly defined the system with --system ...
    [[ -n "$SYSTEMS_ARRAY" ]] && return 0

    local installed_systems=

    installed_systems=$(
        xmlstarlet sel -t -v \
          "/systemList/system/name" \
          "$ES_SYSTEMS_CFG"
    )
    
    [[ -z "$installed_systems" ]] && return 1

    # ignoring retropie menu
    installed_systems="${installed_systems/retropie/}"

    SYSTEMS_ARRAY+=($installed_systems)
}


# Get the useful data for a theme of a specific system. The "system" global
# variable must be filled.
function get_data_from_theme_xml() {
    if [[ -z "$1" ]]; then
        echo "ERROR: get_data_from_theme_xml(): missing argument."
        echo "Available options: background font logo tile bg_color"
        exit 1
    fi

    if [[ -z "$SYSTEM" ]]; then
        echo "ERROR: get_data_from_theme_xml(): the system is undefined."
        exit 1
    fi

    local xml_path=
    local system_theme_dir=
    local xml_file=
    local data=""
    local dir=

    case "$1" in
    "background")
        xml_path="/theme/view[contains(@name,'system')]/image[@name='background']/path"
        ;;
    "tile")
        xml_path="/theme/view[contains(@name,'system')]/image[@name='background']/tile"
        ;;
    "bg_color")
        xml_path="/theme/view[contains(@name,'system')]/image[@name='background']/color"
        ;;
    "logo")
        xml_path="/theme/view[contains(@name,'detailed')]/image[@name='logo']/path"
        ;;
    "font")
        xml_path="/theme/view[contains(@name,'detailed')]/textlist/fontPath"
        ;;
    *)
        echo "ERROR: get_data_from_theme_xml(): invalid argument"
        exit 1
        ;;
    esac

    system_theme_dir=$(
        xmlstarlet sel -t -v \
          "/systemList/system[name='$SYSTEM']/theme" \
          "$ES_SYSTEMS_CFG"
    )

    if [[ -z "$system_theme_dir" ]]; then
        echo "WARNING: \"$SYSTEM\" system not found in $ES_SYSTEMS_CFG" >&2
        return 1
    fi

    xml_file="$THEME_DIR/$system_theme_dir/theme.xml"

    # dealing with <include>s
    while [[ -n "$xml_file" ]]; do
        data=$(
            xmlstarlet sel -t -v \
              "$xml_path" \
              "$xml_file" 2> /dev/null
        )

        [[ -n "$data" ]] && break
    
        # TODO: check what's going wrong with the io theme.
        # if don't find the wanted data on the theme.xml, let's see if there's
        # some <include>d file in it and look for the data there.
        local included_xml=$(
            xmlstarlet sel -t -v \
              "/theme/include" \
              "$xml_file" 2> /dev/null
        )
        [[ -z "$included_xml" ]] && return 1
        xml_file="$(dirname $xml_file)/$included_xml"
    done

    [[ -z "$data" ]] && return

    if [[ "$1" = "tile" || "$1" = "bg_color" ]]; then
        echo "$data"
        return
    fi
    
    # dealing with known issues in themes
    if [[ "$THEME" = "carbon" ]]; then
        if [[ "$1" = "logo" ]]; then
            # due to color problems, we use system3.png for gameandwatch
            # and system2.png for steam
            # TODO: deal with the gamecube also...
            case "$system" in
            "gameandwatch")
                data="${data/%system.svg/system3.svg}"
                ;;
            "steam")
                data="${data/%system.svg/system2.svg}"
                ;;
            esac
        fi
    fi

    echo "$(dirname $xml_file)/$data"
} # end of get_data_from_theme_xml()



function prepare_background() {
    local background=
    local bg_color=
    local colorize=

    # getting the background file
    background=$(get_data_from_theme_xml background)
    [[ -z "$background" ]] && return 1

    # getting the background color
    if [[ -n "$SOLID_BG_COLOR" ]]; then
        bg_color="$SOLID_BG_COLOR"
    else
        bg_color="#$(get_data_from_theme_xml bg_color)"
    fi

    if [[ -n "$bg_color" && "$bg_color" != "#" ]]; then
        if [[ "$SOLID_BG_COLOR_FLAG" ]]; then
            colorize="100,100,100"
        else
            colorize="25,25,25"
        fi

        convert -fill "$bg_color" -colorize "$colorize" \
          "$background" "$TMP_BACKGROUND"
        background="$TMP_BACKGROUND"
    fi

    convert_cmd=(convert)
    if [[ "$(get_data_from_theme_xml tile)" =~ ^[Tt][Rr][Uu][Ee]$ ]]; then
        convert_cmd+=(-size 1024x576 "tile:")
    else
        convert_cmd+=(-resize 'x576' " ") # the trailing space is needed
    fi
    
    ${convert_cmd[@]}"$background" "$TMP_LAUNCHING"
    return $?
}



function add_logo() {
    [[ "$NO_LOGO" = "1" ]] && return

    local logo=

    logo=$(get_data_from_theme_xml logo)
    if [[ -z "$logo" ]]; then
        echo "WARNING: No logo found for \"$SYSTEM\" system."
        return 1
    fi

    convert -background none \
      -resize "450x176" \
      "$logo" "$TMP_LOGO"
    
    if ! [[ -f "$TMP_LOGO" ]]; then
        echo "WARNING: we had some problem when converting \"$SYSTEM\" logo image."
        return 1
    fi

    convert "$TMP_LAUNCHING" \
      -gravity center "$TMP_LOGO" \
      -composite "$TMP_LAUNCHING"

    return $?
}



function add_text() {
    local font=

    font=$(get_data_from_theme_xml font)
    if [[ -z "$font" ]]; then
        echo "WARNING: No font found for \"$SYSTEM\" system."
        return 1
    fi

    convert "$TMP_LAUNCHING" \
      -gravity center \
      -font "$font" \
      -weight 700 \
      -pointsize 24 \
      -fill "$LOADING_TEXT_COLOR" \
      -annotate +0+170 "$LOADING_TEXT" \
      "$TMP_LAUNCHING" \
    && convert "$TMP_LAUNCHING" \
      -gravity center \
      -font "$font" \
      -weight 700 \
      -pointsize 14 \
      -fill "$PRESS_BUTTON_TEXT_COLOR" \
      -annotate +0+230 "$PRESS_BUTTON_TEXT" \
      "$TMP_LAUNCHING"

    return $?
}



function create_launching_image() {
    if [[ -z "$SYSTEM" ]]; then
        echo "ERROR: create_launching_image(): the system is undefined."
        exit 1
    fi

    rm -f "$TMP_BACKGROUND" "$TMP_LAUNCHING"

    if ! prepare_background; then
        echo "WARNING: failed to prepare the background image for \"$SYSTEM\" system!" >&2
        return 1
    fi

    if ! add_logo; then
        echo "WARNING: failed to add the logo image for \"$SYSTEM\" system!" >&2
        return 1
    fi

    if ! add_text; then
        echo "WARNING: failed to add text to the image for \"$SYSTEM\" system!" >&2
        return 1
    fi

    # XXX: decide if this quality reducing is needed.
    convert "$TMP_LAUNCHING" -quality 80 "$FINAL_IMAGE.$EXT"
} # end of create_launching_image


# start here ################################################################

trap safe_exit SIGHUP SIGINT SIGQUIT SIGKILL SIGTERM

check_dep

get_options $@

if ! get_systems; then
    echo "ERROR: failed to get the installed systems!" >&2
    exit 1
fi

proceed

for SYSTEM in ${SYSTEMS_ARRAY[@]}; do
    if ! create_launching_image ; then
        echo "WARNING: The launching image for \"$SYSTEM\" was NOT created." >&2
        FAILED_SYSTEMS+=($SYSTEM)
        continue
    fi


    if [[ "$NO_ASK" != "1" ]]; then
        show_image "$FINAL_IMAGE.$EXT"
        dialog \
          --yesno "Do you accept this as the launching image for \"$SYSTEM\" system?" \
          8 45 \
          || continue
    fi

    if ! mv "$FINAL_IMAGE.$EXT" "$DESTINATION_DIR/$SYSTEM/launching.$EXT"; then
        echo "WARNING: unable to put the created image in \"$DESTINATION_DIR/$SYSTEM\"!" >&2
        FAILED_SYSTEMS+=($SYSTEM)
        continue
    fi
done


fail_msg=$(
    [[ -n "$FAILED_SYSTEMS" ]] \
    && echo "Failed to create/save image for the following systems: ${FAILED_SYSTEMS[@]}"
)

dialog \
  --title " INFO " \
  --msgbox "LAUNCHING IMAGE GENERATION COMPLETED!\n\n$fail_msg" \
  10 60
