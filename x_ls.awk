# drwxr-xr-x    8 edwinjhlee  staff       256  6  2  2020 serverless
# -rw-r--r--@   1 edwinjhlee  staff    108154  5 26  2020 share.jpg
# drwxr-xr-x    4 edwinjhlee  staff       128  7 21  2020 ssh

BEGIN {

    if (out_color_priv == 0)     out_color_priv = "\033[0;35m"
    if (out_color_folder == 0)     out_color_folder = "\033[1m"
    if (out_color_file == 0)     out_color_file = "\033[0m"

    if (out_color_user == 0)     out_color_user = "\033[34m"
    if (out_color_group == 0)     out_color_group = "\033[32m"
    if (out_color_other == 0)     out_color_other = "\033[31m"

    if (out_color_name == 0)  out_color_name = "\033[34m"


    out_color_end = "\033[0m"
}

NR!=1{
    priv=$1
    priv_d=substr(priv, 1, 1)
    priv_user=substr(priv, 2, 3)
    priv_group=substr(priv, 5, 3)
    priv_other=substr(priv, 8, 3)

    if (priv_d == "d") {
        pp=out_color_folder priv_d out_color_user priv_user out_color_group priv_group out_color_other priv_other
    } else {
        pp=out_color_file   priv_d out_color_user priv_user out_color_group priv_group out_color_other priv_other
    }

    number=$2
    owner=$3
    group=$4
    size=$5

    name=$9

    if (match(name, /^\./)) {
        name="\033[36m" name
    }
    name= out_color_name name

    if (NR % 4 != 0) {
        print "\033[27m"    pp "\033[30m" "      " name
    } else {
        print "\033[7m"     pp "\033[30m" "      " name
    }

}
