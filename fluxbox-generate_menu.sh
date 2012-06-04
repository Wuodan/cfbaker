#!/bin/sh
#
# generate_menu for Fluxbox
#
# Copyright (c) 2005 Dung N. Lam <dnlam@users.sourceforge.net>
# Copyright (c) 2002-2004 Han Boetes <han@mijncomputer.nl>
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

# Portability notes:
# To guarantee this script works on all platforms that support fluxbox
# please keep the following restrictions in mind:
#
# - don't use [ "a" == "a" ]; use [ "a" = "a" ]    (found with help from FreeBSD user relaxed)
# - don't use if ! command;, use command; if [ $? -ne 0 ];
# - don't use [ -e file ] use [ -r file ]
# - don't use $(), use ``
# - don't use ~, use ${HOME}
# - don't use id -u or $UID, use whoami
# - getopts won't work on all platforms, but the config-file can
#   compensate for that.
# - OpenBSD and Solaris grep do not have the -m option
# - various software like grep/sed/perl may be not present or not
#   the version you have. for example grep '\W' only works on gnu-grep.
#   Keep this in mind, use bare basic defaults.
# - Do _NOT_ suggest to use #!/bin/bash. Not everybody uses bash.
#   Non portable features like getopts in this script can be achieved in
#   other ways.


# Functions
display_usage() {
    cat << EOF
Usage: fluxbox-generate_menu [-kgrBh] [-t terminal] [-w url] [-b browser]
         [-m menu-title] [-o /path] [-u /path] [-p /path] [-n /path] [-q /path]
         [-d /path ] [-ds] [-i /path] [-is] [-su]
EOF
}

display_help() {
    display_usage
    cat << EOF

Options:

    -k  Insert a KDE menu
    -g  Add a Gnome menu
    -B  Enable backgrounds menu
    -su Enable sudo commands
    -r  Don't remove empty menu-entries; for templates

    -d  Other path(s) to recursively search for *.desktop files
    -ds Wider search for *.desktop files (takes more time)
    -i  Other path(s) to search for icons
        e.g., "/usr/kde/3.3/share/icons/crystalsvg/16x16/*"
    -is Wider search for icons (worth the extra time)
    -in Skip icon search

    -t  Favourite terminal
    -w  Homepage for console-browsers. Default is fluxbox.org
    -b  Favourite browser
    -m  Menu-title; default is "Fluxbox"
    -o  Outputfile; default is ~/.fluxbox/menu
    -u  User sub-menu; default is ~/.fluxbox/usermenu

    -h  Display this help
    -a  Display the authors of this script

  Only for packagers:

    -p  Prefix; default is /usr
    -n  Gnome-prefix; /opt, /usr, /usr/X11R6 and /usr/local autodetected
    -q  KDE-prefix; idem dito


Files:
    ~/.fluxbox/usermenu     Your own submenu which will be included in the menu
    ~/.fluxbox/menuconfig   rc file for fluxbox-generate_menu

EOF
}

#'
display_authors() {
    cat << EOF

fluxbox-generate_menu was brought to you by:

    Henrik Kinnunen:    Project leader.
    Han Boetes:         Packaging, debugging and scripts.
    Simon Bowden:       Cleanups and compatibility for SUN.
    Jeramy B. Smith:    Packaging assistance, Gnome and KDE menu system.
    Filippo Pappalardo: Italian locales and -t option.
    $WHOAMI:            Innocent bystander.

EOF
}

testoption() {
    if [ -z "$3" -o -n "`echo $3|grep '^-'`" ]; then
        echo "Error: The option $2 requires an argument." >&2
        exit 1
    fi
    case $1 in
        ex) # executable
            if find_it "$3"; then
                :
            else
                echo "Error: The option $2 needs an executable as argument, and \`$3' is not." >&2
            fi
            ;;
        di) # directory
            if [ -d "$3" ]; then
                :
            else
                echo "Error: The option $2 needs a directory as argument, and \`$3' is not." >&2
            fi
            ;;
        fl) # file
            if [ -r "$3" ]; then
                :
            else
                echo "Error: The option $2 needs a readable file as argument, and \`$3' is not." >&2
            fi
            ;;
        sk) # skip
            :
            ;;
    esac
}

find_it() {
    [ -n "$1" ] && hash $1 2> /dev/null && shift && "$@"
}

find_it_options() {
    [ -n "$1" ] && hash $1 2> /dev/null
}

#echo "replaceWithinString: $1, $2, $3" >&2
#echo ${1//$2/$3} # causes error in BSD even though not used
replaceWithinString(){
    echo $1 | awk "{ gsub(/$2/, \"$3\"); print }"
}

convertIcon(){
    if [ ! -f "$1" ] ; then 
        echo "Icon file not found: $1" >&2
        return 1
    fi

    if [ "$1" = "$2" ]; then
        # $dnlamVERBOSE "Files are in the same location: $1 = $2" >&2
        # not really an error; just nothing to do.
        return 0;
    fi

    local BASENAME
    BASENAME="${1##*/}"

    # make sure it is an icon by checking if it has an extension
    if [ "$BASENAME" = "${BASENAME%%.*}" ]; then
        # $dnlamVERBOSE "File $1 does not have a filename extention." >&2
        return 1;
    fi

    # don't have to convert xpm files
    case "$1" in
        *.xpm)
            echo "$1"
            return 0;
        ;;
    esac

    # may not have to convert png if imlib is enabled
    if [ "$PNG_ICONS" = "yes" ]; then
        case "$1" in
            *.png)
                echo "$1"
                return 0;
            ;;
        esac
    fi

    # convert all others icons and save it as xpm format under directory $2
    entry_icon="$2/${BASENAME%.*}.xpm"
    if [ -f "${entry_icon}" ]; then
        : echo "File exists. To overwrite, type: convert \"$1\" \"$entry_icon\"" >&2
    else
        if hash convert 2> /dev/null; then
            convert "$1" "$entry_icon"
            # echo convert "$1" , "$entry_icon" >> $ICONMAPPING
        else
            echo "Please install ImageMagick's convert utility" >&2
        fi
    fi
    echo "$entry_icon"
}

removePath(){
    execname="$1"
    progname="${execname%% *}"
    # separate program name and its parameters
    if [ "$progname" = "$execname" ]; then
        # no params
        # remove path from only program name
        execname="${progname##*/}"
    else
        params="${execname#* }"
        # remove path from only program name
        execname="${progname##*/} $params"
    fi
    echo $execname
}

doSearchLoop(){
    for ICONPATH in "$@"; do
        ## $dnlamVERBOSE ": $ICONPATH" >> $ICONMAPPING
          [ -d "$ICONPATH" ] || continue
        #echo -n "."
        # # $dnlamVERBOSE ":: $ICONPATH/$temp_icon" >> $ICONMAPPING
        if [ -f "$ICONPATH/$temp_icon" ]; then
            echo "$ICONPATH/$temp_icon"
            return 0;
        else # try different extensions; 
            # remove extension
            iconNOext="${temp_icon%%.*}"
            [ -d "$ICONPATH" ] && for ICONEXT in .xpm .png .gif ; do
                ## echo "::: $ICONPATH/$iconNOext$ICONEXT" >> $ICONMAPPING
                realpath=`find "$ICONPATH" -type f -name "$iconNOext$ICONEXT" | head -n 1`
                if [ -n "$realpath" ]; then
                    echo $realpath
                    return 0;
                fi
            done
        fi
    done
    #echo "done"
    return 1
}

doSearch(){
    # remove '(' from '(fluxbox ...) | ...'
    execname=`replaceWithinString "$1" "\("`
    temp_icon="$2"
    # $dnlamVERBOSE "# Searching for icon $temp_icon for $execname" >> $ICONMAPPING

    # check in $ICONMAPPING before searching directories
    entry_icon=`grep "^\"${execname}\"" $ICONMAPPING | head -n 1 | grep -o '<.*>'`
    if [ -n "$entry_icon" ]; then
        entry_icon=`replaceWithinString "$entry_icon" "<"`
        entry_icon=`replaceWithinString "$entry_icon" ">"`
        echo $entry_icon
        return 0;
    fi
    # echo "$ICONMAPPING for $execname: $entry_icon"

    # the following paths include a user-defined variable, listing paths to search for icons
    # echo -n "for $temp_icon"
    eval doSearchLoop $USER_ICONPATHS \
      "$FB_ICONDIR" \
      "/usr/share/${execname%% *}" \
      ${OTHER_ICONPATHS} \


}

searchForIcon(){
    # remove '&' and everything after it
    entry_exec="${1%%&*}"
    entry_icon="$2"
    # $dnlamVERBOSE echo "searchForIcon \"$entry_exec\" \"$entry_icon\"" >&2

    # get the basename and parameters of entry_exec -- no path
    entry_exec=`removePath "${entry_exec}"`
    [ -z "$entry_exec" ] && { echo "Exec is NULL $1 with icon $2"; return 1; }

    # search for specified icon if it does not exists
    if [ -n "$entry_icon" ] && [ ! "$entry_exec" = "$entry_icon" ] && [ ! -f "$entry_icon" ]; then
        # to search for icon in other paths,
        # get basename
        temp_icon="${entry_icon##*/}"
        # remove parameters
        temp_icon="${temp_icon#* }"
        # clear entry_icon until temp_icon is found
        unset entry_icon

        if [ ! -f "$entry_icon" ]; then
            entry_icon=`doSearch "$entry_exec" "$temp_icon"`
        fi
    fi

    # remove parameters
    execname="${entry_exec%% *}"

    # echo "search for icon named $execname.{xpm,png,gif}"
    if [ ! -f "$entry_icon" ]; then
        entry_icon=`doSearch "$entry_exec" "$execname"`
    fi

    # -----------  done with search ------------
    # $dnlamVERBOSE echo "::: $entry_icon" >&2

    # convert icon file, if needed
    if [ -f "$entry_icon" ] && [ -n "yes$ConvertIfNecessary" ]; then
        entry_icon=`convertIcon "$entry_icon" "$USERFLUXDIR/icons"`
        # $dnlamVERBOSE echo ":::: $entry_icon" >&2
    fi

    # remove path to icon; just get basename
    icon_base="${entry_icon##*/}"
    # remove extension
    icon_base="${icon_base%%.*}"
    # echo "^.${entry_exec}.[[:space:]]*<.*/${icon_base}\....>" 
    if [ -f "$entry_icon" ]; then
    # if icon exists and entry does not already exists, add it
        if ! grep -q -m 1 "^.${entry_exec}.[[:space:]]*<.*/${icon_base}\....>" $ICONMAPPING 2> /dev/null; then
            echo -e "\"${entry_exec}\" \t <${entry_icon}>" >> $ICONMAPPING
        else 
            : echo "#    mapping already exists for ${entry_exec}" >> $ICONMAPPING
        fi
    else
        echo "# No icon file found for $entry_exec" >> $ICONMAPPING
    fi
}

toSingleLine(){ echo "$@"; }
createIconMapping(){
    # $dnlamVERBOSE "# creating `date`" >> $ICONMAPPING
    # $dnlamVERBOSE "# using desktop files in $@" >> $ICONMAPPING
    # $dnlamVERBOSE "# searching for icons in `eval toSingleLine $OTHER_ICONPATHS`" >> $ICONMAPPING
    # need to determine when to use .fluxbox/icons/$execname.xpm over those listed in iconmapping
    # $dnlamVERBOSE echo "createIconMapping: $@"
    for DIR in "$@" ; do
        if [ -d "$DIR" ]; then
            # $dnlamVERBOSE echo "# ------- Looking in $DIR" >&2 
            # >> $ICONMAPPING
            find "$DIR" -type f -name "*.desktop" | while read DESKTOP_FILE; do 
                # echo $DESKTOP_FILE; 
                #entry_name=`grep '^[ ]*Name=' $DESKTOP_FILE | head -n 1`
                #entry_name=${entry_name##*=}
                entry_exec=`grep '^[ ]*Exec=' "$DESKTOP_FILE" | head -n 1`
                entry_exec=${entry_exec##*=}
                entry_exec=`replaceWithinString "$entry_exec" "\""`
                if [ -z "$entry_exec" ]; then
                    entry_exec=${DESKTOP_FILE%%.desktop*}
                fi

                entry_icon=`grep '^[ ]*Icon=' "$DESKTOP_FILE" | head -n 1`
                entry_icon=${entry_icon##*=}

                # $dnlamVERBOSE echo "--- $entry_exec $entry_icon" >&2
                case "$entry_icon" in
                    "" | mime_empty | no_icon )
                        : echo "no icon for $entry_exec"
                    ;;
                    *)
                        searchForIcon "$entry_exec" "$entry_icon"
                    ;;
                esac
            done
        fi
    done
    # $dnlamVERBOSE "# done `date`" >> $ICONMAPPING
}

lookupIcon() {
    if [ ! -f "$ICONMAPPING" ]; then
        echo "!!! Icon map file not found: $ICONMAPPING" >&2
        return 1
    fi

    execname="$1"
    shift
    [ -n "$1" ] && echo "!! Ignoring extra parameters: $*" >&2

    [ -z "$execname" ] && { echo "execname is NULL; cannot lookup"; return 1; }
    execname=`removePath "$execname"`

    #echo "grepping ${execname}"
    iconString=`grep "^\"${execname}\"" $ICONMAPPING | head -n 1 | grep -o '<.*>'`
    # $dnlamVERBOSE "lookupIcon $execname, $iconString" >&2

    if [ -z "$iconString" ] ; then
        iconString=`grep "^\"${execname%% *}" $ICONMAPPING | head -n 1 | grep -o '<.*>'`
    fi

    if [ -z "$iconString" ] && [ -z "$PARSING_DESKTOP" ] ; then
        ## $dnlamVERBOSE "lookupIcon: Searching ...  should only be needed for icons not gotten from *.desktop (manual-created ones): $execname" >&2
        searchForIcon "$execname" "$execname"
        [ -n "$entry_icon" ] && iconString="<$entry_icon>"
    fi

    # [ -n "$iconString" ] && echo "  Found icon for $execname: $iconString" >&2
    echo $iconString
}

append() {
     if [ -z "${INSTALL}" ]; then
        # $dnlamVERBOSE echo "append: $*" >&2
        iconString="`echo $* | grep -o '<.*>'`"
        # echo "iconString=$iconString" >&2
        if [ -z "$iconString" ] && [ -z "$NO_ICON" ]; then
            echo -n "      $* " >> ${MENUFILENAME}
            # get the program name between '{}' from parameters            
            execname="$*"
            execname=${execname#*\{}
            execname=${execname%%\}*}
            # $dnlamVERBOSE echo "execname=$execname" >&2
            # if execname hasn't changed from original $*, then no '{...}' was given
            if [ ! "$execname" = "$*" ]; then
                case "$execname" in
                    $DEFAULT_TERM*)
                        # remove quotes
                        execname=`replaceWithinString "$execname" "\""`
                        # remove "$DEFAULT_TERM -e "
                        # needed in case calling another program (e.g., vi) via "xterm -e"                    
                        execname=${execname##*$DEFAULT_TERM -e }
                    ;;
                esac
                # lookup execname in icon map file
                iconString=`lookupIcon "$execname"`
                #[ -n "$iconString" ] || echo "No icon found for $execname"
            fi
            echo "${iconString}" >> ${MENUFILENAME}
        else
            echo "      $*" >> ${MENUFILENAME}
        fi
    else
        echo "      $*" >> ${MENUFILENAME}
    fi
}

append_menu() {
    echo "$*" >> ${MENUFILENAME}
}

append_submenu() {
    [ "${REMOVE}" ] && echo >> ${MENUFILENAME} # only an empty line in templates
    append_menu "[submenu] ($1)"
}

append_menu_end() {
    append_menu '[end]'
    [ "${REMOVE}" ] && echo >> ${MENUFILENAME} # only an empty line in templates
}

menu_entry() {
    if [ -f "$1" ]; then
        #                   space&tab here
        entry_name=`grep '^[     ]*Name=' "$1" | head -n 1 | cut -d = -f 2`
        entry_exec=`grep '^[     ]*Exec=' "$1" | head -n 1 | cut -d = -f 2`
        if [ -n "$entry_name" -a -n "$entry_exec" ]; then
            append "[exec] ($entry_name) {$entry_exec}"
        fi
    fi
}

menu_entry_dir() {
    for b in  "$*"/*.desktop; do
        menu_entry "${b}"
    done
}

menu_entry_dircheck() {
    if [ -d "$*" ]; then
        menu_entry_dir "$*"
    fi
}


# recursively build a menu from the listed directories
# the dirs are merged
recurse_dir_menu () {
    ls "$@"/ 2>/dev/null | sort | uniq | while read name; do
        for dir in "$@"; do
            if [ -n "$name" -a -d "$dir/$name" ]; then
                # recurse
                append_submenu "${name}"
                # unfortunately, this is messy since we can't easily expand
                # them all. Only allow for 3 atm. Add more if needed
                recurse_dir_menu ${1:+"$1/$name"}  ${2:+"$2/$name"} ${3:+"$3/$name"}
                append_menu_end
                break; # found one, it'll pick up all the rest
            fi
            # ignore it if it is a file, since menu_entry_dir picks those up
        done
    done

    # Make entries for current dir after all submenus
    for dir in "$@"; do
        menu_entry_dircheck "${dir}"
    done
}


normal_find() {
	if [ "$1" == "eclipse" ]; then
		echo "$1"
	fi
    while [ "$1" ]; do
        find_it $1     append "[exec]   ($1) {$1}"
        shift
    done
}

cli_find() {
    while [ "$1" ]; do
        find_it $1     append "[exec]   ($1) {${DEFAULT_TERM} -e $1}"
        shift
    done
}

sudo_find() {
    [ "${DOSUDO}" = yes ] || return
    while [ "$1" ]; do
        find_it $1     append "[exec]   ($1 (as root)) {${DEFAULT_TERM} -e sudo $1}"
        shift
    done
}

clean_up() {
[ -f "$ICONMAPPING" ] && rm -f "$ICONMAPPING"

# Some magic to clean up empty menus
rm -f ${MENUFILENAME}.tmp
touch ${MENUFILENAME}.tmp
counter=10 # prevent looping in odd circumstances
until [ $counter -lt 1 ] || \
    cmp ${MENUFILENAME} ${MENUFILENAME}.tmp >/dev/null 2>&1; do
    [ -s ${MENUFILENAME}.tmp ] && mv ${MENUFILENAME}.tmp ${MENUFILENAME}
    counter=`expr $counter - 1`
    grep -v '^$' ${MENUFILENAME}|sed -e "/^\[submenu].*/{
n
N
/^\[submenu].*\n\[end]/d
}"|sed -e "/^\[submenu].*/{
N
/^\[submenu].*\n\[end]/d
}" > ${MENUFILENAME}.tmp
done
rm -f ${MENUFILENAME}.tmp
}
# End functions


WHOAMI=`whoami`
[ "$WHOAMI" = root ] && PATH=/bin:/usr/bin:/usr/local/bin:/usr/X11R6/bin

# Check for Imlib2-support
if fluxbox -info 2> /dev/null | grep -q "^IMLIB"; then
    PNG_ICONS="yes"
else
    # better assume to assume "no"
    PNG_ICONS="no"
fi

# menu defaults (if translation forget to set one of them)

MENU_ENCODING=UTF-8 # (its also ascii)

ABOUTITEM='About'
ANALYZERMENU='Analyzers'
BACKGROUNDMENU='Backgrounds'
BACKGROUNDMENUTITLE='Set the Background'
BROWSERMENU='Browsers'
BURNINGMENU='Burning'
CONFIGUREMENU='Configure'
EDITORMENU='Editors'
EDUCATIONMENU='Education'
EXITITEM='Exit'
FBSETTINGSMENU='Fluxbox menu'
FILEUTILSMENU='File utils'
FLUXBOXCOMMAND='Fluxbox Command'
GAMESMENU='Games'
GNOMEMENUTEXT='Gnome-menus'
GRAPHICMENU='Graphics'
KDEMENUTEXT='KDE-menus'
LOCKSCREEN='Lock screen'
MISCMENU='Misc'
MULTIMEDIAMENU='Multimedia'
MUSICMENU='Audio'
NETMENU='Net'
NEWS='News'
OFFICEMENU='Office'
RANDOMBACKGROUND='Random Background'
REGENERATEMENU='Regen Menu'
RELOADITEM='Reload config'
RESTARTITEM='Restart'
RUNCOMMAND='Run'
SCREENSHOT='Screenshot'
STYLEMENUTITLE='Choose a style...'
SYSTEMSTYLES='System Styles'
SYSTEMTOOLSMENU='System Tools'
TERMINALMENU='Terminals'
TOOLS='Tools'
USERSTYLES='User Styles'
VIDEOMENU='Video'
WINDOWMANAGERS='Window Managers'
WINDOWNAME='Window name'
WORKSPACEMENU='Workspace List'
XUTILSMENU='X-utils'

# Check translation
case ${LC_ALL} in
    ru_RU*) #Russian locales

# Ah my Russian hero. Please help me update the translation
# $ cp fluxbox-generate-menu.in fluxbox-generate-menu.in.orig
# $ $EDITOR fluxbox-generate-menu.in
# $ diff -u fluxbox-generate-menu.in.orig fluxbox-generate-menu.in > fbgm.diff
# email fbgm.diff to han@mijncomputer.nl

        MENU_ENCODING=KOI8-R

        BACKGROUNDMENU='����'
        BACKGROUNDMENUTITLE='���������� ����'
        BROWSERMENU='��������'
        CONFIGUREMENU='���������'
        EDITORMENU='���������'
        EXITITEM='�����'
        FBSETTINGSMENU='FB-���������'
        FILEUTILSMENU='�������� �������'
        FLUXBOXCOMMAND='��������� �������'
        GAMESMENU='����'
        GNOMEMENUTEXT='Gnome-����'
        GRAPHICMENU='�������'
        KDEMENUTEXT='KDE-����'
        LOCKSCREEN='������������� �����'
        MISCMENU='������'
        MUSICMENU='����'
        NETMENU='����'
        OFFICEMENU='������� ����������'
        RANDOMBACKGROUND='��������� ����'
        REGENERATEMENU='������� ���� ������'
        RELOADITEM='�������������'
        RESTARTITEM='�������������'
        RUNCOMMAND='���������'
        SCREENSHOT='������ ������'
        STYLEMENUTITLE='�������� �����'
        SYSTEMSTYLES='��������� �����'
        TERMINALMENU='���������'
        TOOLS='�������'
        USERSTYLES='���������������� �����'
        WINDOWMANAGERS='��������� ����'
        WINDOWNAME='��� ����'
        WORKSPACEMENU='������� ������������'
        XUTILSMENU='X-�������'
        ;;

    cs_CZ.ISO*) # Czech locales (ISO-8859-2 encodings)

        MENU_ENCODING=ISO-8859-2

        ABOUTITEM='O programu...'
        BACKGROUNDMENU='Pozad�'
        BACKGROUNDMENUTITLE='Nastaven� pozad�'
        BROWSERMENU='Prohl��e�e'
        BURNINGMENU='Vypalov�n�'
        CONFIGUREMENU='Konfigurace'
        EDITORMENU='Editory'
        EXITITEM='Ukon�it'
        FBSETTINGSMENU='Fluxbox Menu'
        FILEUTILSMENU='Souborov� utility'
        FLUXBOXCOMMAND='P��kaz Fluxboxu'
        GAMESMENU='Hry'
        GNOMEMENUTEXT='Gnome-menu'
        GRAPHICMENU='Grafika'
        KDEMENUTEXT='KDE-menu'
        LOCKSCREEN='Zamknout obrazovku'
        MISCMENU='R�zn�'
        MULTIMEDIAMENU='Multim�dia'
        MUSICMENU='Audio'
        NETMENU='Internet'
        NEWS='News'
        OFFICEMENU='Kancel��'
        RANDOMBACKGROUND='N�hodn� pozad�'
        REGENERATEMENU='Obnoven� menu'
        RELOADITEM='Obnoven� konfigurace'
        RESTARTITEM='Restart'
        RUNCOMMAND='Spustit program...'
        SCREENSHOT='Screenshot'
        STYLEMENUTITLE='Volba stylu...'
        SYSTEMTOOLSMENU='Syst�mov� utility'
        SYSTEMSTYLES='Syst�mov� styly'
        TERMINALMENU='Termin�ly'
        TOOLS='N�stroje'
        USERSTYLES='U�ivatelsk� styly'
        VIDEOMENU='Video'
        WINDOWMANAGERS='Okenn� mana�ery'
        WINDOWNAME='Jm�no okna'
        WORKSPACEMENU='Seznam ploch'
        XUTILSMENU='X-utility'
        ;;

    de_DE*) # german locales

        MENU_ENCODING=ISO-8859-15

        BACKGROUNDMENU='Hintergrundbilder'
        BACKGROUNDMENUTITLE='Hintergrundbild setzen'
        BROWSERMENU='Internet-Browser'
        CONFIGUREMENU='Einstellungen'
        EDITORMENU='Editoren'
        EXITITEM='Beenden'
        FBSETTINGSMENU='Fluxbox-Einstellungen'
        FILEUTILSMENU='Datei-Utilities'
        FLUXBOXCOMMAND='Fluxbox Befehl'
        GAMESMENU='Spiele'
        GNOMEMENUTEXT='Gnome-Menues'
        GRAPHICMENU='Grafik'
        KDEMENUTEXT='Kde-Menues'
        LOCKSCREEN='Bildschirmsperre'
        MISCMENU='Sonstiges'
        MUSICMENU='Musik'
        NETMENU='Netzwerk'
        OFFICEMENU='Bueroprogramme'
        RANDOMBACKGROUND='Zufaelliger Hintergrund'
        REGENERATEMENU='Menu-Regeneration'
        RELOADITEM='Konfiguration neu laden'
        RESTARTITEM='Neustarten'
        RUNCOMMAND='Ausf�hren'
        SCREENSHOT='Bildschirmfoto'
        STYLEMENUTITLE='Einen Stil auswaehlen...'
        SYSTEMSTYLES='Systemweite Stile'
        TERMINALMENU='Terminals'
        TOOLS='Helfer'
        USERSTYLES='Eigene Stile'
        WINDOWMANAGERS='Window Manager'
        WINDOWNAME='Window Name'
        WORKSPACEMENU='Arbeitsflaechenliste'
        XUTILSMENU='X-Anwendungen'
        ;;
    sv_SE*) #Swedish locales
# Ah my Swedish hero. Please help me update the translation
# $ cp fluxbox-generate-menu.in fluxbox-generate-menu.in.orig
# $ $EDITOR fluxbox-generate-menu.in
# $ diff -u fluxbox-generate-menu.in.orig fluxbox-generate-menu.in > fbgm.diff
# email fbgm.diff to han@mijncomputer.nl

        MENU_ENCODING=ISO-8859-1

        BACKGROUNDMENU='Bakgrunder'
        BACKGROUNDMENUTITLE='S�tt bakgrund'
        BROWSERMENU='Webbl�sare'
        CONFIGUREMENU='Konfiguration'
        EDITORMENU='Editorer'
        EXITITEM='Avsluta'
        FBSETTINGSMENU='FB-inst�llningar'
        FILEUTILSMENU='Filverktyg'
        FLUXBOXCOMMAND='Fluxbox kommando'
        GAMESMENU='Spel'
        GNOMEMENUTEXT='Gnome-menyer'
        GRAPHICMENU='Grafik'
        KDEMENUTEXT='KDE-menyer'
        LOCKSCREEN='L�s sk�rm'
        MISCMENU='Blandat'
        MULTIMEDIAMENU='Multimedia'
        MUSICMENU='Musik'
        NETMENU='Internet'
        OFFICEMENU='Office'
        RANDOMBACKGROUND='Slumpm�ssig bakgrund'
        REGENERATEMENU='Generera meny'
        RELOADITEM='Ladda om konfig'
        RESTARTITEM='Starta om'
        RUNCOMMAND='K�r'
        SCREENSHOT='Sk�rmdump'
        STYLEMENUTITLE='V�lj en stil'
        SYSTEMSTYLES='Stiler'
        TERMINALMENU='Terminaler'
        TOOLS='Verktyg'
        USERSTYLES='Stiler'
        VIDEOMENU='Video'
        WINDOWMANAGERS='F�nsterhanterare'
        WINDOWNAME='F�nsternamn'
        WORKSPACEMENU='Arbetsytor'
        XUTILSMENU='X-program'
        ;;
    nl_*) #Nederlandse locales

        MENU_ENCODING=ISO-8859-15

        BACKGROUNDMENU='Achtergrond'
        BACKGROUNDMENUTITLE='Kies een achtergrond'
        BROWSERMENU='Browsers'
        CONFIGUREMENU='Instellingen'
        EDITORMENU='Editors'
        EXITITEM='Afsluiten'
        FBSETTINGSMENU='FB-Instellingen'
        FILEUTILSMENU='Verkenners'
        FLUXBOXCOMMAND='Fluxbox Commando'
        GAMESMENU='Spelletjes'
        GNOMEMENUTEXT='Gnome-menu'
        GRAPHICMENU='Grafisch'
        KDEMENUTEXT='KDE-menu'
        LOCKSCREEN='Scherm op slot'
        MISCMENU='Onregelmatig'
        MUSICMENU='Muziek'
        NETMENU='Internet'
        OFFICEMENU='Office'
        RANDOMBACKGROUND='Willekeurige Achtergrond'
        REGENERATEMENU='Nieuw Menu'
        RELOADITEM='Vernieuw instellingen'
        RESTARTITEM='Herstart'
        RUNCOMMAND='Voer uit'
        SCREENSHOT='Schermafdruk'
        STYLEMENUTITLE='Kies een stijl'
        SYSTEMSTYLES='Systeem Stijlen'
        TERMINALMENU='Terminals'
        TOOLS='Gereedschap'
        USERSTYLES='Gebruikers Stijlen'
        WINDOWMANAGERS='Venster Managers'
        WINDOWNAME='Venster Naam'
        WORKSPACEMENU='Werkveld menu'
        XUTILSMENU='X-Gereedschap'
        ;;
    fi_FI*) #Finnish locales

        MENU_ENCODING=ISO-8859-1

        ABOUTMENU='Tietoja ohjelmasta'
        ABOUTITEM='Tietoja ohjelmasta'
        BACKGROUNDMENU='Taustakuvat'
        BACKGROUNDMENUTITLE='M��rit� taustakuva'
        BROWSERMENU='Selaimet'
        CONFIGUREMENU='Asetukset'
        EDITORMENU='Editorit'
        EXITITEM='Lopeta'
        FBSETTINGSMENU='Fluxboxin asetukset'
        FILEUTILSMENU='Tiedostoty�kalut'
        FLUXBOXCOMMAND='Fluxbox komentorivi'
        GAMESMENU='Pelit'
        GNOMEMENUTEXT='Gnomen valikot'
        GRAPHICMENU='Grafiikka'
        KDEMENUTEXT='KDE:n valikot'
        LOCKSCREEN='Lukitse n�ytt�'
        MISCMENU='Sekalaista'
        MUSICMENU='Musiikki'
        NETMENU='Verkko'
        OFFICEMENU='Toimisto-ohjelmat'
        RANDOMBACKGROUND='Satunnainen taustakuva'
        REGENERATEMENU='P�ivit� valikko'
        RELOADITEM='P�ivit�'
        RESTARTITEM='K�ynnist� uudelleen'
        RUNCOMMAND='Suorita'
        SCREENSHOT='Kuvakaappaus'
        STYLEMENUTITLE='Valitse tyyli'
        SYSTEMSTYLES='J�rjestelm�n tyylit'
        TERMINALMENU='Terminaalit'
        TOOLS='Ty�kalut'
        USERSTYLES='K�ytt�j�n tyylit'
        WINDOWMANAGERS='Ikkunointiohjelmat'
        WINDOWNAME='Ikkunan nimi'
        WORKSPACEMENU='Ty�alueet'
        XUTILSMENU='X-Ohjelmat'
        ;;
    ja_JP*) #Japanese locales
# Ah my Japanese hero. Please help me update the translation
# $ cp fluxbox-generate-menu.in fluxbox-generate-menu.in.orig
# $ $EDITOR fluxbox-generate-menu.in
# $ diff -u fluxbox-generate-menu.in.orig fluxbox-generate-menu.in > fbgm.diff
# email fbgm.diff to han@mijncomputer.nl

        MENU_ENCODING=eucJP

        BACKGROUNDMENU='�ط�'
        BACKGROUNDMENUTITLE='�طʤ�����'
        BROWSERMENU='�֥饦��'
        CONFIGUREMENU='����'
        EDITORMENU='���ǥ���'
        EXITITEM='��λ'
        FBSETTINGSMENU='Fluxbox������'
        FILEUTILSMENU='�ե��������'
        FLUXBOXCOMMAND='Fluxbox���ޥ��'
        GAMESMENU='������'
        GNOMEMENUTEXT='Gnome��˥塼'
        GRAPHICMENU='����'
        KDEMENUTEXT='KDE��˥塼'
        LOCKSCREEN='�����꡼����å�'
        MISCMENU='��������'
        MUSICMENU='����'
        NETMENU='�ͥåȥ��'
        OFFICEMENU='���ե���(Office)'
        RANDOMBACKGROUND='�ط�(������)'
        REGENERATEMENU='��˥塼�ƹ���'
        RELOADITEM='���ɤ߹���'
        RESTARTITEM='�Ƶ�ư'
        RUNCOMMAND='���ޥ�ɤμ¹�'
        SCREENSHOT='�����꡼�󥷥�å�'
        STYLEMENUTITLE='������������...'
        SYSTEMSTYLES='��������'
        TERMINALMENU='�����ߥʥ�'
        TOOLS='�ġ���'
        USERSTYLES='��������'
        WINDOWMANAGERS='������ɥ��ޥ͡�����'
        WINDOWNAME='������ɥ�̾'
        WORKSPACEMENU='������ڡ���'
        XUTILSMENU='X�桼�ƥ���ƥ�'
        ;;
    fr_FR*) # french locales
# Ah my french hero. Please help me update the translation
# $ cp fluxbox-generate-menu.in fluxbox-generate-menu.in.orig
# $ $EDITOR fluxbox-generate-menu.in
# $ diff -u fluxbox-generate-menu.in.orig fluxbox-generate-menu.in > fbgm.diff
# email fbgm.diff to han@mijncomputer.nl

        MENU_ENCODING=ISO-8859-15

        ANALYZERMENU='Analyseurs'
        BACKGROUNDMENU="Fond d'�cran"
        BACKGROUNDMENUTITLE="Changer le fond d'�cran"
        BROWSERMENU='Navigateurs'
        CONFIGUREMENU='Configurer'
        EDITORMENU='�diteurs'
        EXITITEM='Sortir'
        FBSETTINGSMENU='Configurer Fluxbox'
        FILEUTILSMENU='Outils fichiers'
        FLUXBOXCOMMAND='Commande Fluxbox'
        GAMESMENU='Jeux'
        GNOMEMENUTEXT='Menus Gnome'
        GRAPHICMENU='Graphisme'
        KDEMENUTEXT='Menus KDE'
        LOCKSCREEN="Verrouiller l'�cran"
        MISCMENU='Divers'
        MULTIMEDIAMENU='Multim�dia'
        MUSICMENU='Musique'
        NETMENU='R�seau'
        OFFICEMENU='Bureautique'
        RANDOMBACKGROUND="Fond d'�cran al�atoire"
        REGENERATEMENU='R�g�n�rer le menu'
        RELOADITEM='Recharger la configuration'
        RESTARTITEM='Red�marrer Fluxbox'
        RUNCOMMAND='Run'
        SCREENSHOT="Capture d'�cran"
        STYLEMENUTITLE='Choisir un style...'
        SYSTEMSTYLES='Styles Syst�me'
        SYSTEMTOOLSMENU='Outils Syst�me'
        TERMINALMENU='Terminaux'
        TOOLS='Outils'
        USERSTYLES='Styles Utilisateur'
        VIDEOMENU='Vid�o'
        WINDOWMANAGERS='Gestionnaires de fen�tres'
        WINDOWNAME='Nom de la fen�tre'
        WORKSPACEMENU='Liste des bureaux'
        XUTILSMENU='Outils X'
        ;;
    it_IT*) # italian locales

        MENU_ENCODING=ISO-8859-1

        BACKGROUNDMENU='Sfondi'
        BACKGROUNDMENUTITLE='Imposta lo sfondo'
        BROWSERMENU='Browsers'
        CONFIGUREMENU='Configurazione'
        EDITORMENU='Editori'
        EXITITEM='Esci'
        FBSETTINGSMENU='Preferenze'
        FILEUTILSMENU='Utilit�'
        FLUXBOXCOMMAND='Comando Fluxbox'
        GAMESMENU='Giochi'
        GNOMEMENUTEXT='Gnome'
        GRAPHICMENU='Grafica'
        KDEMENUTEXT='KDE'
        LOCKSCREEN='Blocca lo schermo'
        MISCMENU='Varie'
        MUSICMENU='Musica'
        NETMENU='Internet'
        OFFICEMENU='Office'
        RANDOMBACKGROUND='Sfondo casuale'
        REGENERATEMENU='Rigenera il menu'
        RELOADITEM='Rileggi la configurazione'
        RESTARTITEM='Riavvia'
        RUNCOMMAND='Esegui'
        SCREENSHOT='Schermata'
        STYLEMENUTITLE='Scegli uno stile'
        SYSTEMSTYLES='Stile'
        TERMINALMENU='Terminali'
        TOOLS='Attrezzi'
        USERSTYLES='Stile'
        WINDOWMANAGERS='Gestori finestre'
        WINDOWNAME='Nome della finestra'
        WORKSPACEMENU='Aree di lavoro'
        XUTILSMENU='Utilit� X'
        ;;
    ro_RO*) # Romanian locales
# Ah my Romanian hero. Please help me update the translation
# $ cp fluxbox-generate-menu.in fluxbox-generate-menu.in.orig
# $ $EDITOR fluxbox-generate-menu.in
# $ diff -u fluxbox-generate-menu.in.orig fluxbox-generate-menu.in > fbgm.diff
# email fbgm.diff to han@mijncomputer.nl

        MENU_ENCODING=ISO-8859-15

        BACKGROUNDMENU='Fundaluri'
        BACKGROUNDMENUTITLE='Alege fundalul'
        BROWSERMENU='Navigatoare'
        CONFIGUREMENU='Configurare'
        EDITORMENU='Editoare'
        EXITITEM='Iesire'
        FBSETTINGSMENU='Meniul Fluxbox'
        FILEUTILSMENU='Utilitare de fisier'
        FLUXBOXCOMMAND='Comanda Fluxbox'
        GAMESMENU='Jocuri'
        GNOMEMENUTEXT='Meniu Gnome'
        GRAPHICMENU='Grafica'
        KDEMENUTEXT='Meniu KDE'
        LOCKSCREEN='Incuie ecranul'
        MISCMENU='Diverse'
        MULTIMEDIAMENU='Multimedia'
        MUSICMENU='Muzica'
        NETMENU='Retea'
        OFFICEMENU='Office'
        RANDOMBACKGROUND='Fundal aleator'
        REGENERATEMENU='Regenereaza meniul'
        RELOADITEM='Reincarca configuratia'
        RESTARTITEM='Restart'
        RUNCOMMAND='Lanseaza'
        SCREENSHOT='Captura ecran'
        STYLEMENUTITLE='Alege un stil...'
        SYSTEMSTYLES='Stiluri sistem'
        TERMINALMENU='Terminale'
        TOOLS='Unelte'
        USERSTYLES='Stiluri utilizator'
        WINDOWMANAGERS='WindowManagers'
        WINDOWNAME='Nume fereastra'
        WORKSPACEMENU='Lista workspace-uri'
        XUTILSMENU='Utilitare X'
        ;;
    es_ES*) # spanish locales

        MENU_ENCODING=ISO-8859-15

        ABOUTITEM='Acerca'
        BACKGROUNDMENU='Fondos'
        BACKGROUNDMENUTITLE='Seleccionar Fondo'
        BROWSERMENU='Navegadores'
        BURNINGMENU='Herramientas de grabaci�n'
        CONFIGUREMENU='Configurar'
        EDITORMENU='Editores'
        EDUCATIONMENU='Educaci�n'
        EXITITEM='Salir'
        FBSETTINGSMENU='Men� fluxbox'
        FILEUTILSMENU='Utilidades'
        FLUXBOXCOMMAND='Comandos de Fluxbox'
        GAMESMENU='Juegos'
        GNOMEMENUTEXT='Men�s Gnome'
        GRAPHICMENU='Gr�ficos'
        KDEMENUTEXT='Men�s KDE'
        LOCKSCREEN='Bloquear Pantalla'
        MISCMENU='Varios'
        MULTIMEDIAMENU='Multimedia'
        MUSICMENU='M�sica'
        NETMENU='Red'
        NEWS='Noticias'
        OFFICEMENU='Oficina'
        RANDOMBACKGROUND='Fondo Aleatoreo'
        REGENERATEMENU='Regenerar Men�'
        RELOADITEM='Reconfigurar'
        RESTARTITEM='Reiniciar'
        RUNCOMMAND='Ejecutar'
        SCREENSHOT='Captura de Pantalla'
        STYLEMENUTITLE='Escoge un Estilo...'
        SYSTEMSTYLES='Estilos del Sistema'
        TERMINALMENU='Terminales'
        TOOLS='Herramienta'
        USERSTYLES='Estilos del Usuario'
        VIDEOMENU='Video'
        WINDOWMANAGERS='Gestores de Ventanas'
        WINDOWNAME='Nombre de Ventana'
        WORKSPACEMENU='Lista de Escritorios'
        XUTILSMENU='Utilidades X'
        ;;
    pl_PL*) # Polish locales
# Ah my Russian hero. Please help me update the translation
# $ cp fluxbox-generate-menu.in fluxbox-generate-menu.in.orig
# $ $EDITOR fluxbox-generate-menu.in
# $ diff -u fluxbox-generate-menu.in.orig fluxbox-generate-menu.in > fbgm.diff
# email fbgm.diff to han@mijncomputer.nl

        MENU_ENCODING=ISO-8859-2

        BACKGROUNDMENU='Tapety'
        BACKGROUNDMENUTITLE='Ustaw tapet�'
        BROWSERMENU='Przegl�darki'
        CONFIGUREMENU='Konfiguracja'
        EDITORMENU='Edytory'
        EXITITEM='Wyj�cie'
        FBSETTINGSMENU='Menu Fluxbox'
        FILEUTILSMENU='Narz�dzia do plik�w'
        FLUXBOXCOMMAND='Polecenia Fluxbox'
        GAMESMENU='Gry'
        GNOMEMENUTEXT='Menu Gnome'
        GRAPHICMENU='Grafika'
        KDEMENUTEXT='Menu KDE'
        LOCKSCREEN='Zablokuj ekran'
        MISCMENU='R�ne'
        MULTIMEDIAMENU='Multimedia'
        MUSICMENU='Muzyka'
        NETMENU='Sie�'
        OFFICEMENU='Aplikacje biurowe'
        RANDOMBACKGROUND='Losowa tapeta'
        REGENERATEMENU='Wygeneruj menu'
        RELOADITEM='Od�wie� konfiguracj�'
        RESTARTITEM='Restartuj'
        RUNCOMMAND='Uruchom...'
        SCREENSHOT='Zrzut ekranu'
        STYLEMENUTITLE='Wybierz styl...'
        SYSTEMSTYLES='Style systemowe'
        TERMINALMENU='Terminale'
        TOOLS='Narz�dzia'
        USERSTYLES='Style u�ytkownika'
        WINDOWMANAGERS='Menad�ery okien'
        WINDOWNAME='Nazwy okien'
        WORKSPACEMENU='Lista pulpit�w'
        XUTILSMENU='Narz�dzia X'
        ;;
    pt_PT*) # Portuguese locales

        MENU_ENCODING=ISO-8859-1

        ABOUTMENU="Sobre"
        BACKGROUNDMENU='Imagens de Fundo'
        BACKGROUNDMENUTITLE='Definir Imagem de Fundo'
        BROWSERMENU='Browsers'
        BURNINGMENU='Ferramentas de Grava��o'
        CONFIGUREMENU='Configura��o'
        EDITORMENU='Editores'
        EDUCATIONMENU='Educa��o'
        EXITITEM='Sair'
        FBSETTINGSMENU='Menu Fluxbox'
        FILEUTILSMENU='Utilit�rios de Ficheiros'
        FLUXBOXCOMMAND='Comando Fluxbox'
        GAMESMENU='Jogos'
        GNOMEMENUTEXT='Menu Gnome'
        GRAPHICMENU='Gr�ficos'
        KDEMENUTEXT='Menu KDE'
        LOCKSCREEN='Trancar Ecr�'
        MISCMENU='Misc.'
        MULTIMEDIAMENU='Multim�dia'
        MUSICMENU='�udio'
        NETMENU='Rede'
        NEWS='Not�cias'
        OFFICEMENU='Escrit�rio'
        RANDOMBACKGROUND='Imagem Aleat�ria'
        REGENERATEMENU='Regenerar Menu'
        RELOADITEM='Recarregar configura��o'
        RESTARTITEM='Reiniciar'
        RUNCOMMAND='Executar'
        SCREENSHOT='Capturar Ecr�'
        STYLEMENUTITLE='Escolha um estilo...'
        SYSTEMSTYLES='Estilos do Sistema'
        SYSTEMTOOLSMENU='Ferramentas de Sistema'
        TERMINALMENU='Terminais'
        TOOLS='Ferramentas'
        USERSTYLES='Estilos do Utilizador'
        VIDEOMENU='V�deo'
        WINDOWMANAGERS='Gestores de Janelas'
        WINDOWNAME='Nome da Janela'
        WORKSPACEMENU='Lista de �reas de Trabalho'
        XUTILSMENU='Utilit�rios X'
        ;;
    nb_NO*) # Norwegian locales

        MENU_ENCODING=UTF-8

        ABOUTITEM='Om'
        BACKGROUNDMENU='Bakgrunner'
        BACKGROUNDMENUTITLE='Velg bakgrunn'
        BROWSERMENU='Nettlesere'
        CONFIGUREMENU='Oppsett'
        EDITORMENU='Tekstredigeringsprogram'
        EDUCATIONMENU='Lek og lær'
        EXITITEM='Avslutt'
        FBSETTINGSMENU='FluxBox-meny'
        FILEUTILSMENU='Filverktøy'
        FLUXBOXCOMMAND='FluxBox-kommando'
        GAMESMENU='Spill'
        GNOMEMENUTEXT='Gnome-menyer'
        GRAPHICMENU='Grafikk'
        KDEMENUTEXT='KDE-menyer'
        LOCKSCREEN='Lås skjermen'
        MISCMENU='Diverse'
        MULTIMEDIAMENU='Multimedia'
        MUSICMENU='Lyd'
        NETMENU='Nett'
        NEWS='Nyheter'
        OFFICEMENU='Kontor'
        RANDOMBACKGROUND='Tilfeldig bakgrunn'
        REGENERATEMENU='Regen Menu'
        RELOADITEM='Last oppsett på nytt'
        RESTARTITEM='Start på nytt'
        RUNCOMMAND='Kjør'
        SCREENSHOT='Ta bilde'
        STYLEMENUTITLE='Velg en stil . . .'
        SYSTEMSTYLES='System-stiler'
        TERMINALMENU='Terminaler'
        TOOLS='Verktøy'
        USERSTYLES='Bruker-stiler'
        VIDEOMENU='Video'
        WINDOWMANAGERS='Vindusbehandlere'
        WINDOWNAME='Vindunavn'
        WORKSPACEMENU='Liste over arbeidsområder'
        XUTILSMENU='X-verktøy'
        ;;
    *)
        ;;
esac

# Set Defaults
USERFLUXDIR="${HOME}/.fluxbox"
MENUFILENAME="${MENUFILENAME:=${USERFLUXDIR}/menu}"
MENUTITLE="${MENUTITLE:=Fluxbox}"
HOMEPAGE="${HOMEPAGE:=fluxbox.org}"
USERMENU="${USERMENU:=${USERFLUXDIR}/usermenu}"
MENUCONFIG="${MENUCONFIG:=${USERFLUXDIR}/menuconfig}"
DOSUDO="no"

# Read the menuconfig file if it exists or else create it.
# But not during install time, use envvar for sun
if [ ! "${INSTALL}" = Yes ]; then
    if [ -r ${MENUCONFIG} ]; then
        . ${MENUCONFIG}
    else
        if [ ! "$WHOAMI" = root ]; then # this is only for users.
            if touch ${MENUCONFIG}; then
                cat << EOF > ${MENUCONFIG}
# This file is read by fluxbox-generate_menu.  If you don't like a
# default you can change it here.  Don't forget to remove the # in front
# of the line.

# Your favourite terminal. Put the command in quotes if you want to use
# options. Put a backslash in before odd chars
# MY_TERM='Eterm --tint \#123456'
# MY_TERM='aterm -tint \$(random_color)'

# Your favourite browser. You can also specify options.
# MY_BROWSER=mozilla

# Name of the outputfile
# MENUFILENAME=${USERFLUXDIR}/menu

# MENUTITLE=\`fluxbox -version|cut -d " " -f-2\`

# standard url for console-browsers
# HOMEPAGE=fluxbox.org

# location with your own menu-entries
# USERMENU=~/.fluxbox/usermenu

# Put the launcher you would like to use here
# LAUNCHER=fbrun
# LAUNCHER=fbgm

# Options for fbrun
# FBRUNOPTIONS='-font 10x20 -fg grey -bg black -title run'

# --- PREFIX'es
# These are prefixes; So if fluxbox is installed in /usr/bin/fluxbox
# your prefix is: /usr

# fluxbox-generate already looks in /usr/X11R6, /usr, /usr/local and /opt so
# there should be no need to specify them.
#
# PREFIX=/usr
# GNOME_PREFIX=/opt/gnome
# KDE_PREFIX=/opt/kde


# Separate the list of background dirs with colons ':'
# BACKGROUND_DIRS="${USERFLUXDIR}/backgrounds/:/usr/share/fluxbox/backgrounds/:/usr/share/wallpapers"


# --- Boolean variables.
# Setting a variable to ``no'' won't help. Comment them out if you don't
# want them. Settings are overruled by the command-line options.

# Include all backgrounds in your backgrounds-directory
# BACKGROUNDMENUITEM=yes

# Include KDE-menus
# KDEMENU=yes

# Include Gnome-menus
# GNOMEMENU=yes

# Enable sudo commands
# DOSUDO=yes

# Don't cleanup the menu
# REMOVE=no

# Don't add icons to the menu
# NO_ICON=yes

EOF
            else
                echo "Warning: I couldn't create ${MENUCONFIG}" >&2
            fi
        fi
    fi
fi

BACKUPOPTIONS=$@
if [ -n "$BACKUPOPTIONS" ]; then
    FBGM_CMD="fluxbox-generate_menu $BACKUPOPTIONS"
else
    FBGM_CMD=fluxbox-generate_menu
fi
# Get options.
while [ $# -gt 0 ]; do
    case "$1" in
        -B) BACKGROUNDMENUITEM=yes; shift;;
        -k) KDEMENU=yes; shift;;
        -g) GNOMEMENU=yes; shift;;
        -in) NO_ICON=yes; shift;;
        -is) OTHER_ICONPATHS="
                /usr/share/icons
                /usr/share/icons/mini
                /usr/share/pixmaps
                /usr/local/share/icons
                /usr/local/share/icons/mini
                /usr/local/share/pixmaps
                /usr/share/xclass/icons
                /usr/share/xclass/pixmaps
                /usr/local/share/xclass/icons
                /usr/local/share/xclass/pixmaps
                /usr/X11R6/share/icons/default/16x16
                /usr/X11R6/share/icons/kde/16x16
                /usr/X11R6/share/icons/hicolor/16x16
                /usr/local/X11R6/share/icons/default/16x16
                /usr/local/X11R6/share/icons/kde/16x16
                /usr/local/X11R6/share/icons/hicolor/16x16
            "
            shift;;
        -ds) OTHER_DESKTOP_PATHS="
                /usr/share/mimelnk 
                /usr/share/applications
                /usr/share/xsessions 
                /usr/share/services 
            "
            # /usr/share/apps \
            shift;;
        -i) USER_ICONPATHS=${2};
            #needs testing 
            for aPath in $2; do
                testoption di $1 $aPath; 
            done
            shift 2;;
        -d) USER_DESKTOP_PATHS=${2};
            #needs testing 
            for aPath in $2; do
                testoption di $1 $aPath; 
            done
            shift 2;;
        -t) MY_TERM=${2}; testoption ex $1 $2; shift 2;;
        -b) MY_BROWSER=${2}; testoption ex $1 $2; shift 2;;
        -o) MENUFILENAME=${2}; shift 2; CHECKINIT=NO ;;
        -p) PREFIX=${2}; testoption di $1 $2; shift 2;;
        -n) GNOME_PREFIX=${2}; testoption di $1 $2; shift 2;;
        -q) KDE_PREFIX=${2}; testoption di $1 $2; shift 2;;
        -m) MENUTITLE=${2}; testoption sk $1 $2; shift 2;;
        -w) HOMEPAGE=${2}; testoption sk $1 $2; shift 2;;
        -u) USERMENU=${2}; testoption fl $1 $2; shift 2;;
	-su) DOSUDO=yes; shift;;
        -r) REMOVE=no; shift;;
        -h) display_help ; exit 0 ;;
        -a) display_authors ; exit 0 ;;
        --*) echo "fluxbox-generate_menu doesn't recognize -- gnu-longopts."
            echo 'Use fluxbox-generate_menu -h for a long help message.'
            display_usage
            exit 1 ;;
        -[a-zA-Z][a-zA-Z]*)
            # split concatenated single-letter options apart
            FIRST="$1"; shift
            set -- `echo "$FIRST" | sed 's/^-\(.\)\(.*\)/-\1 -\2/'` "$@"
            ;;
        -*)
            echo 1>&2 "fluxbox-generate_menu: unrecognized option "\`"$1'"
            display_usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Check defaults

# Can we actually create ${MENUFILENAME}
touch ${MENUFILENAME} 2> /dev/null
if [ $? -ne 0 ]; then
    echo "Fatal error: can't create or write to $MENUFILENAME" >&2
    exit 1
fi

# backup menu
if [ -w "${MENUFILENAME}" ]; then
    if [ -f ${MENUFILENAME}.firstbak ]; then
        cp ${MENUFILENAME} ${MENUFILENAME}.firstbak
    fi
    if [ -s "${MENUFILENAME}" ]; then
       mv ${MENUFILENAME} ${MENUFILENAME}.bak
    fi
fi

# prefix
PREFIX="${PREFIX:=/usr}"
if [  -z "${PREFIX}" -o ! -d "${PREFIX}" ]; then
    hash fluxbox
    PREFIX=`hash | grep fluxbox | sed 's,.*\t/,/,' | sed 's,/bin/fluxbox$,,'`
fi


# gnome prefix
for GNOME_PREFIX in "${GNOME_PREFIX}" /usr/local /usr/X11R6 /usr /opt "${PREFIX}"; do
    if [ -n "${GNOME_PREFIX}" -a -d "$GNOME_PREFIX/share/gnome" ]; then
        break;
    fi
done
# Will remain $PREFIX if all else fails

# kde prefix
for KDE_PREFIX in "${KDE_PREFIX}" /usr/local /usr/X11R6 /usr /opt "${PREFIX}"; do
    if [ -n "${KDE_PREFIX}" -a -d "$KDE_PREFIX/share/applnk" ]; then
        break;
    fi
done

if [ -z "${INSTALL}" ] && [ -z "${NO_ICON}" ]; then
    # [ -z "$dnlamVERBOSE" ] && dnlamVERBOSE=": echo"   # for debugging
    FB_ICONDIR="$USERFLUXDIR/icons"
    [ -r "$FB_ICONDIR" ] || mkdir "$FB_ICONDIR"
    ICONMAPPING="$USERFLUXDIR/iconmapping"

    if [ "$GNOMEMENU" ] ; then
        OTHER_DESKTOP_PATHS="\"$HOME/.gnome/apps\" \"${GNOME_PREFIX}/share/gnome/apps\" $OTHER_DESKTOP_PATHS"
        #[ "OTHER_ICONPATHS" ] && OTHER_ICONPATHS=
    fi
    if [ "$KDEMENU" ] ; then
        OTHER_DESKTOP_PATHS="\"$HOME/.kde/share/applnk\" \"${KDE_PREFIX}/share/applnk\" $OTHER_DESKTOP_PATHS"
        [ "OTHER_ICONPATHS" ] && OTHER_ICONPATHS="\"$HOME\"/.kde/share/icons/{,*} $OTHER_ICONPATHS"
    fi
    [ "$GNOMEMENU$KDEMENU" ] && OTHER_DESKTOP_PATHS="\"$ETCAPPLNK\" $OTHER_DESKTOP_PATHS"

    checkDirs(){
        #echo checkDirs: $* >&2
        local CHECKED_DIRS=""
        for DIR in "$@"; do
            if [ -d "$DIR" ]; then
                # todo: should check if there are duplicates
                CHECKED_DIRS="$CHECKED_DIRS \"$DIR\""
            fi
        done
        #echo checkDirs - $CHECKED_DIRS >&2
        echo $CHECKED_DIRS
    }

    OTHER_ICONPATHS=`eval checkDirs $OTHER_ICONPATHS`
    OTHER_DESKTOP_PATHS=`eval checkDirs $OTHER_DESKTOP_PATHS`

    # $dnlamVERBOSE "Using USER_DESKTOP_PATHS=\"$USER_DESKTOP_PATHS\" and USER_ICONPATHS=\"$USER_ICONPATHS\""
    # $dnlamVERBOSE "Using OTHER_ICONPATHS=$OTHER_ICONPATHS"
    # $dnlamVERBOSE "Using OTHER_DESKTOP_PATHS=$OTHER_DESKTOP_PATHS"
    # $dnlamVERBOSE "Calling function: createIconMapping"
    
    # $dnlamVERBOSE "Creating $ICONMAPPING" >&2
    touch "$ICONMAPPING"
    eval createIconMapping $USER_DESKTOP_PATHS $OTHER_DESKTOP_PATHS
    # $dnlamVERBOSE "Done createIconMapping."
fi

# directory for the backgrounds
if [ -z "$BACKGROUND_DIRS" ]; then
    BACKGROUND_DIRS="${USERFLUXDIR}/backgrounds/:${PREFIX}/share/fluxbox/backgrounds/"
fi

# find the default terminal
if find_it_options $MY_TERM; then
    DEFAULT_TERM=$MY_TERM
else
    [ -n "$MY_TERM" ] && echo "Warning: you chose an invalid term." >&2
    #The precise order is up for debate.
    for term in Eterm urxvt urxvtc aterm mrxvt rxvt wterm konsole gnome-terminal xterm; do
        if find_it_options $term; then
            DEFAULT_TERM=$term
            break
        fi
    done
fi
# a unix system without any terms. that's odd
if [ -z "$DEFAULT_TERM" ]; then
    cat << EOF >&2

Warning: I can't find any terminal-emulators in your PATH.  Please fix
your PATH or specify your favourite terminal-emulator with the -t option

EOF
    DEFAULT_TERM=xterm
fi

DEFAULT_TERMNAME=`echo $DEFAULT_TERM|awk '{print $1}'`
DEFAULT_TERMNAME=`basename $DEFAULT_TERMNAME`


# find the default browser
if find_it_options $MY_BROWSER; then
    DEFAULT_BROWSER=$MY_BROWSER
else
    [ -n "$MY_BROWSER" ] && echo "Warning: you chose an invalid browser." >&2
    #The precise order is up for debate.
    for browser in firefox mozilla-firefox mozilla-firebird MozillaFirebird opera skipstone mozilla chromium epiphany seamonkey galeon konqueror dillo netscape w3m amaya links lynx; do
        if find_it_options $browser; then
            DEFAULT_BROWSER=$browser
            break
        fi
    done
fi
DEFAULT_BROWSERNAME=`echo $DEFAULT_BROWSER|awk '{print $1}'`
DEFAULT_BROWSERNAME=`basename $DEFAULT_BROWSERNAME`

if [ -z "$LAUNCHER" ]; then
    LAUNCHER=fbrun
fi
if [ -n "$FBRUNOPTIONS" ]; then
    # with this, LAUNCHER should be renamed LAUNCHER_NAME, but then there's
    # backwards-compatibility...
    LAUNCHER_CMD="$LAUNCHER $FBRUNOPTIONS"
else
    LAUNCHER_CMD=$LAUNCHER
fi

# if gxmessage exists, use it; else use xmessage
if find_it gxmessage; then
    XMESSAGE=gxmessage
else
    XMESSAGE=xmessage
fi

# Start of menu
cat << EOF > ${MENUFILENAME}
# Generated by fluxbox-generate_menu
#
# If you read this it means you want to edit this file manually, so here
# are some useful tips:
#
# - You can add your own menu-entries to ~/.fluxbox/usermenu
#
# - If you miss apps please let me know and I will add them for the next
#   release.
#
# - The -r option prevents removing of empty menu entries and lines which
#   makes things much more readable.
#
# - To prevent any other app from overwriting your menu
#   you can change the menu name in ~/.fluxbox/init to:
#     session.menuFile: ~/.fluxbox/my-menu

EOF

echo "[begin] (${MENUTITLE})" >> ${MENUFILENAME}

if [ -n "$MENU_ENCODING" ]; then
    append_menu "[encoding] {$MENU_ENCODING}"
fi

append "[exec] (${DEFAULT_TERMNAME}) {${DEFAULT_TERM}}"

case "$DEFAULT_BROWSERNAME" in
    links|w3m|lynx)  append "[exec] (${DEFAULT_BROWSERNAME}) {${DEFAULT_TERM} -e ${DEFAULT_BROWSER} ${HOMEPAGE}}" ;;
    chromium|epiphany|firefox|firebird|mozilla|seamonkey|phoenix|galeon|dillo|netscape|amaya) append "[exec] (${DEFAULT_BROWSERNAME}) {${DEFAULT_BROWSER}}" ;;
    konqueror) append "[exec] (konqueror) {kfmclient openProfile webbrowsing}" ;;
    opera) append "[exec] (opera) {env QT_XFT=true opera}" ;;
    MozillaFirebird) append "[exec] (firebird) {MozillaFirebird}" ;;
    MozillaFirefox) append "[exec] (firefox) {MozillaFirefox}" ;;
    *) append "[exec] ($DEFAULT_BROWSERNAME) {$DEFAULT_BROWSER}" ;;
esac

find_it "${LAUNCHER}" append "[exec]   (${RUNCOMMAND}) {$LAUNCHER_CMD}"


append_submenu "${TERMINALMENU}"
    normal_find xterm urxvt urxvtc gnome-terminal multi-gnome-terminal Eterm \
        konsole aterm mlterm multi-aterm rxvt mrxvt
append_menu_end


append_submenu "${NETMENU}"
    append_submenu "${BROWSERMENU}"
        normal_find firefox mozilla-firefox MozillaFirefox galeon mozilla chromium epiphany seamonkey dillo netscape vncviewer
        find_it links       append "[exec]   (links-graphic) {links -driver x ${HOMEPAGE}}"
        find_it opera       append "[exec]   (opera) {env QT_XFT=true opera}"
        find_it konqueror   append "[exec]   (konqueror) {kfmclient openProfile webbrowsing}"
        find_it links       append "[exec]   (links) {${DEFAULT_TERM} -e links ${HOMEPAGE}}"
        find_it w3m         append "[exec]   (w3m) {${DEFAULT_TERM} -e w3m ${HOMEPAGE}}"
        find_it lynx        append "[exec]   (lynx) {${DEFAULT_TERM} -e lynx ${HOMEPAGE}}"
    append_menu_end

    append_submenu IM
        normal_find pidgin gaim kopete gnomemeeting sim kadu psi amsn aim ayttm everybuddy gabber ymessenger
        find_it licq        append "[exec]   (licq) {env QT_XFT=true licq}"
        cli_find centericq micq
    append_menu_end

    append_submenu Mail
        normal_find sylpheed kmail evolution thunderbird mozilla-thunderbird \
            sylpheed-claws claws-mail
        cli_find mutt pine
    append_menu_end

    append_submenu News
        normal_find liferea pears pan
        cli_find slrn tin
    append_menu_end

    append_submenu IRC
        normal_find xchat xchat-2 ksirc vyqchat lostirc logui konversation kvirc skype
        cli_find irssi epic4 weechat ninja
        find_it BitchX        append "[exec]   (BitchX) {${DEFAULT_TERM} -e BitchX -N}" || \
        find_it bitchx        append "[exec]   (BitchX) {${DEFAULT_TERM} -e bitchx -N}"
        find_it ircii         append "[exec]   (ircii) {${DEFAULT_TERM} -e ircii -s}"
    append_menu_end

    append_submenu P2P
        normal_find gtk-gnutella lopster nicotine pyslsk xmule amule \
            valknut dcgui-qt dc_qt quickdc asami azureus
        cli_find TekNap giFTcurs
    append_menu_end

    append_submenu FTP
        normal_find gftp IglooFTP-PRO kbear
        cli_find ncftp pftp ftp lftp yafc
    append_menu_end

    append_submenu SMB
      normal_find LinNeighborhood jags SambaSentinel
    append_menu_end

    append_submenu "${ANALYZERMENU}"
	  normal_find xnmap nmapfe wireshark ettercap
	  sudo_find xnmap nmapfe wireshark ettercap
    append_menu_end

    normal_find x3270 wpa_gui

append_menu_end

append_submenu "${EDITORMENU}"
    normal_find gvim bluefish nedit gedit xedit kword kwrite kate anjuta \
        wings xemacs emacs kvim cream evim scite Ted eclipse
    cli_find nano vim vi zile jed joe
    find_it     emacs  append "[exec]   (emacs-nw) {${DEFAULT_TERM} -e emacs -nw}"
    find_it     xemacs append "[exec]   (xemacs-nw) {${DEFAULT_TERM} -e xemacs -nw}"
append_menu_end

append_submenu "${EDUCATIONMENU}"
    normal_find celestia scilab geomview scigraphica oregano xcircuit electric \
        pymol elem chemtool xdrawchem gperiodic stellarium   
    find_it drgeo          append "[exec] (Dr. Geo) {drgeo}"
    find_it     R          append "[exec] (R) {${DEFAULT_TERM} -e R --gui=gnome}"
    cli_find maxima grace yacas octave gnuplot grass coq acl
append_menu_end

append_submenu "${FILEUTILSMENU}"
    find_it     konqueror append "[exec] (konqueror) {kfmclient openProfile filemanagement}"
    normal_find gentoo thunar krusader kcommander linuxcmd rox tuxcmd krename xfe xplore worker endeavour2 evidence
    find_it     nautilus append "[exec] (nautilus) {nautilus --no-desktop --browser}"
    cli_find mc
append_menu_end

append_submenu "${MULTIMEDIAMENU}"
       append_submenu "${GRAPHICMENU}"
               normal_find gimp gimp2 gimp-2.2 inkscape sodipodi xv gqview showimg xpaint kpaint kiconedit \
                   ee xzgv xscreensaver-demo xlock gphoto tuxpaint krita skencil
               find_it xnview           append "[exec] (xnview browser) {xnview -browser}"
               find_it blender          append "[exec] (blender) {blender -w}"
               find_it gears            append "[exec] (Mesa gears) {gears}"
               find_it morph3d          append "[exec] (Mesa morph) {morph3d}"
               find_it reflect          append "[exec] (Mesa reflect) {reflect}"
       append_menu_end

       append_submenu "${MUSICMENU}"
               normal_find xmms noatun alsaplayer gqmpeg aumix xmixer gnome-alsamixer gmix kmix kscd \
                   grecord kmidi xplaycd soundtracker grip easytag audacity \
                   zinf rhythmbox kaboodle beep-media-player amarok tagtool \
                   audacious bmpx
               cli_find cdcd cplay alsamixer orpheus mp3blaster
       append_menu_end


       append_submenu "${VIDEOMENU}"
           normal_find xine gxine aviplay gtv gmplayer xmovie xcdroast xgdb \
               realplay xawtv fxtv ogle goggles vlc
           find_it dvdrip append "[exec] (dvdrip) {nohup dvdrip}"
       append_menu_end

       append_submenu "${XUTILSMENU}"
           normal_find xfontsel xman xload xbiff editres viewres xclock \
               xmag wmagnify gkrellm gkrellm2 vmware portagemaster agave 
           find_it xrdb append "[exec] (Reload .Xdefaults) {xrdb -load \$HOME/.Xdefaults}"
       append_menu_end
append_menu_end


append_submenu "${OFFICEMENU}"
    normal_find xclock xcalc kcalc grisbi qbankmanager evolution
    find_it gcalc           append "[exec] (gcalc) {gcalc}" || \
        find_it gnome-calculator append "[exec] (gcalc) {gnome-calculator}"
    find_it ical            append "[exec] (Calendar)   {ical}"

    # older <=1.1.3 apparently have stuff like swriter, not sowriter
    for ext in s so oo xoo; do
        find_it ${ext}ffice2 && (
            find_it ${ext}ffice2        append "[exec] (Open Office 2)  {${ext}ffice2}"
            find_it ${ext}base2         append "[exec] (OO Base 2)      {${ext}base2}"
            find_it ${ext}calc2         append "[exec] (OO Calc 2)      {${ext}calc2}"
            find_it ${ext}writer2       append "[exec] (OO Writer 2)    {${ext}writer2}"
            find_it ${ext}web2          append "[exec] (OO Web 2)       {${ext}web2}"
            find_it ${ext}html2         append "[exec] (OO HTML 2)      {${ext}html2}"
            find_it ${ext}impress2      append "[exec] (OO Impress 2)   {${ext}impress2}"
            find_it ${ext}draw2         append "[exec] (OO Draw 2)      {${ext}draw2}"
            find_it ${ext}math2         append "[exec] (OO Math 2)      {${ext}math2}"
            find_it ${ext}fromtemplate2 append "[exec] (OO Templates 2) {${ext}fromtemplate2}"
        )
        find_it ${ext}ffice && (
            find_it ${ext}ffice        append "[exec] (Open Office)      {${ext}ffice}"
            find_it ${ext}base         append "[exec] (OO Base)          {${ext}base}"
            find_it ${ext}calc         append "[exec] (OO Calc)          {${ext}calc}"
            find_it ${ext}writer       append "[exec] (OO Writer)        {${ext}writer}"
            find_it ${ext}web          append "[exec] (OO Web)           {${ext}web}"
            find_it ${ext}impress      append "[exec] (OO Impress)       {${ext}impress}"
            find_it ${ext}draw         append "[exec] (OO Draw)          {${ext}draw}"
            find_it ${ext}math         append "[exec] (OO Math)          {${ext}math}"
            find_it ${ext}fromtemplate append "[exec] (OO Templates)     {${ext}fromtemplate}"
            find_it ${ext}padmin       append "[exec] (OO Printer Admin) {${ext}padmin}"
            find_it mrproject          append "[exec] (Mr.Project)       {mrproject}"
        )
    done

    normal_find abiword kword wordperfect katoob lyx acroread xpdf gv ghostview
    normal_find dia xfig
    normal_find gnumeric
append_menu_end

append_submenu "${GAMESMENU}"
    normal_find bzflag gnibbles gnobots2 tuxpuck gataxx glines \
        gnect mahjongg gnomine gnome-stones gnometris gnotravex \
        gnotski iagno knights eboard xboard scid freecell pysol \
        gtali tuxracer xpenguins xsnow xeyes smclone \
        openmortal quake2 quake3 skoosh same-gnome enigma xbill \
        icebreaker scorched3d sol dosbox black-box freeciv \
        freeciv-server frozen-bubble liquidwar qt-nethack \
        nethack-gnome pathological scummvm xqf \
        wesnoth canfeild ace_canfeild golf merlin chickens \
        supertux tuxdash  neverball cube_client blackjack \
        doom doom3 quake4 blackshades gltron kpoker concentration \
        torrent scramble kiki xmoto warsow wormux zsnes
    cli_find gnugo xgame

    find_it et append "[exec] (Enemy Territory) {et}"
    find_it ut append "[exec] (Unreal Tournament) {ut}"
    find_it ut2003 append "[exec] (Unreal Tournament 2003) {ut2003}"
    find_it ut2004 append "[exec] (Unreal Tournament 2004) {ut2004}"
append_menu_end

append_submenu "${SYSTEMTOOLSMENU}"
  append_submenu "${BURNINGMENU}"
    normal_find k3b cdbakeoven graveman xcdroast arson eroaster gcombust \
                gtoaster kiso kover gtkcdlabel kcdlabel cdw cdlabelgen 
    cli_find     mp3burn cdrx burncenter
  append_menu_end

  normal_find firestarter gtk-lshw gproftd gpureftpd guitoo porthole gtk-iptables \
              gtk-cpuspeedy
  find_it    fireglcontrol   append "[exec] (ATI Config) {fireglcontrol}"
  cli_find    top htop iotop ntop powertop
append_menu_end




# We'll only use this once
ETCAPPLNK=/etc/X11/applnk
PARSING_DESKTOP="true"
# gnome menu
if [ "${GNOMEMENU}" ]; then
    append_submenu "${GNOMEMENUTEXT}"
    recurse_dir_menu "${GNOME_PREFIX}/share/gnome/apps" "$HOME/.gnome/apps" ${ETCAPPLNK}
    append_menu_end
    unset ETCAPPLNK
fi

# kde submenu
if [ -d "${KDE_PREFIX}/share/applnk/" -a "${KDEMENU}" ]; then
    append_submenu "${KDEMENUTEXT}"
    recurse_dir_menu "${KDE_PREFIX}/share/applnk" "$HOME/.kde/share/applnk" ${ETCAPPLNK}
    append_menu_end
    unset ETCAPPLNK
fi
unset PARSING_DESKTOP

#User menu
if [ -r "${USERMENU}" ]; then
    cat ${USERMENU} >> ${MENUFILENAME}
fi

append_submenu "${FBSETTINGSMENU}"
    append "[config] (${CONFIGUREMENU})"

    append_submenu "Styles"
        append "[include] (/usr/share/fluxbox/menu.d/styles/)"
    append_menu_end

    # Backgroundmenu
    addbackground() {
                picturename=`basename "$1"`
                append "[exec] (${picturename%.???}) {fbsetbg -a \"$1\" }"
    }

    if [ "$BACKGROUNDMENUITEM" = yes ]; then
        IFS=: # set delimetor for find
        NUMBER_OF_BACKGROUNDS=`find $BACKGROUND_DIRS -follow -type f 2> /dev/null|wc -l`
        if [ "$NUMBER_OF_BACKGROUNDS" -gt 0 ]; then
            append_menu "[submenu] (${BACKGROUNDMENU}) {${BACKGROUNDMENUTITLE}}"
            append "[exec] (${RANDOMBACKGROUND}) {fbsetbg -r ${USERFLUXDIR}/backgrounds}"
            if [ "$NUMBER_OF_BACKGROUNDS" -gt 30 ]; then
                menucounter=1 ; counter=1
                append_menu "[submenu] (${BACKGROUNDMENU} $menucounter) {${BACKGROUNDMENUTITLE}}"
                find $BACKGROUND_DIRS -follow -type f|sort|while read i; do
                    counter=`expr $counter + 1`
                    if [ $counter -eq 30 ]; then
                        counter=1
                        menucounter=`expr $menucounter + 1`
                        append_menu_end
                        append_menu "[submenu] (${BACKGROUNDMENU} $menucounter) {${BACKGROUNDMENUTITLE}}"
                    fi
                    addbackground "$i"
                done
                append_menu_end
            else
                find $BACKGROUND_DIRS -follow -type f|sort|while read i; do
                addbackground "$i"
                done
            fi
            append_menu_end
        else
            echo "Warning: You wanted a background-menu but I couldn't find any backgrounds in:
    $BACKGROUND_DIRS" >&2
        fi
    fi

    append "[workspaces] (${WORKSPACEMENU})"

    append_submenu "${TOOLS}"
        normal_find fluxconf fluxkeys fluxmenu
        find_it fbpanel append "[exec] (Fluxbox panel) {fbpanel}"
        find_it $XMESSAGE append \
            "[exec] (${WINDOWNAME}) {xprop WM_CLASS|cut -d \\\" -f 2|$XMESSAGE -file - -center}"
        find_it import append "[exec] (${SCREENSHOT} - JPG) {import screenshot.jpg && display -resize 50% screenshot.jpg}"
        find_it import append "[exec] (${SCREENSHOT} - PNG) {import screenshot.png && display -resize 50% screenshot.png}"
        find_it ${LAUNCHER} append "[exec] (${RUNCOMMAND}) {$LAUNCHER_CMD}"
        find_it switch append "[exec] (gtk-theme-switch) {switch}"
        find_it switch2 append "[exec] (gtk2-theme-switch) {switch2}"
        find_it fluxbox-generate_menu append "[exec] (${REGENERATEMENU}) {$FBGM_CMD}"
    append_menu_end

    append_submenu "${WINDOWMANAGERS}"
    #hard to properly maintain since there are so many exceptions to the rule.
    for wm in mwm twm wmii beryl compiz metacity icewm ion kde sawfish enlightenment fvwm openbox evilwm waimea xfce pekwm xfce4 fvwm2 blackbox ; do
        find_it start${wm} append "[restart] (${wm}) {start${wm}}" ||\
            find_it ${wm} append "[restart] (${wm}) {${wm}}"
    done
        find_it startgnome append "[restart] (gnome) {startgnome}" ||\
            find_it gnome-session append "[restart] (gnome) {gnome-session}"

        find_it startwindowmaker append "[restart] (windowmaker) {startwindowmaker}" ||\
            find_it wmaker append "[restart] (windowmaker) {wmaker}"
    append_menu_end
    find_it xlock append "[exec] (${LOCKSCREEN}) {xlock}" ||\
        find_it xscreensaver-command append "[exec] (${LOCKSCREEN}) {xscreensaver-command -lock}"
    append "[commanddialog] (${FLUXBOXCOMMAND})"
    append "[reconfig] (${RELOADITEM})"
    append "[restart] (${RESTARTITEM})"
    append "[exec] (${ABOUTITEM}) {(fluxbox -v; fluxbox -info | sed 1d) | $XMESSAGE -file - -center}"
    append "[separator]"
    append "[exit] (${EXITITEM})"

    append_menu_end

if [ -n "$MENU_ENCODING" ]; then
    append_menu "[endencoding]"
fi

append_menu_end

# this function removes empty menu items. It can not yet  remove  nested
# empty submenus :\

if [ ! "${REMOVE}" ]; then
    clean_up
fi

# escapes any parentheses in menu label
# e.g.,  "[exec] (konqueror (web))" becomes  "[exec] (konqueror (web\))"
sed 's/(\(.*\)(\(.*\)))/(\1 (\2\\))/' $MENUFILENAME > $MENUFILENAME.tmp
mv -f $MENUFILENAME.tmp $MENUFILENAME

if [ -z "$INSTALL" ]; then
    if [ -z "$CHECKINIT" ]; then
        INITMENUFILENAME=`awk '/menuFile/ {print $2}' $USERFLUXDIR/init`
        INITMENUFILENAME=`replaceWithinString "$INITMENUFILENAME" "~" "$HOME"`
        if [ ! "$INITMENUFILENAME" = "$MENUFILENAME" ]; then 
            echo "Note: In $USERFLUXDIR/init, your \"session.menuFile\" does not point to $MENUFILENAME but to $INITMENUFILENAME" >&2
        fi
    fi
    echo "Menu successfully generated: $MENUFILENAME"
    #echo "  Make sure \"session.menuFile: $MENUFILENAME\" is in $HOME/.fluxbox/init."
    echo 'Use fluxbox-generate_menu -h to read about all the latest features.'
fi
