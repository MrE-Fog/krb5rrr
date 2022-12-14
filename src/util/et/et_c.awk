BEGIN { 
char_shift=64
## "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_";
c2n["A"]=1
c2n["B"]=2
c2n["C"]=3
c2n["D"]=4
c2n["E"]=5
c2n["F"]=6
c2n["G"]=7
c2n["H"]=8
c2n["I"]=9
c2n["J"]=10
c2n["K"]=11
c2n["L"]=12
c2n["M"]=13
c2n["N"]=14
c2n["O"]=15
c2n["P"]=16
c2n["Q"]=17
c2n["R"]=18
c2n["S"]=19
c2n["T"]=20
c2n["U"]=21
c2n["V"]=22
c2n["W"]=23
c2n["X"]=24
c2n["Y"]=25
c2n["Z"]=26
c2n["a"]=27
c2n["b"]=28
c2n["c"]=29
c2n["d"]=30
c2n["e"]=31
c2n["f"]=32
c2n["g"]=33
c2n["h"]=34
c2n["i"]=35
c2n["j"]=36
c2n["k"]=37
c2n["l"]=38
c2n["m"]=39
c2n["n"]=40
c2n["o"]=41
c2n["p"]=42
c2n["q"]=43
c2n["r"]=44
c2n["s"]=45
c2n["t"]=46
c2n["u"]=47
c2n["v"]=48
c2n["w"]=49
c2n["x"]=50
c2n["y"]=51
c2n["z"]=52
c2n["0"]=53
c2n["1"]=54
c2n["2"]=55
c2n["3"]=56
c2n["4"]=57
c2n["5"]=58
c2n["6"]=59
c2n["7"]=60
c2n["8"]=61
c2n["9"]=62
c2n["_"]=63
}
/^#/ { next }
/^[ \t]*(error_table|et)[ \t]+[a-zA-Z][a-zA-Z0-9_]+/ {
	table_number = 0
	table_name = $2
	mod_base = 1000000
	for(i=1; i<=length(table_name); i++) {
	    table_number=(table_number*char_shift)+c2n[substr(table_name,i,1)]
	}

	# We start playing *_high, *low games here because the some
	# awk programs do not have the necessary precision (sigh)
	tab_base_low = table_number % mod_base
	tab_base_high = int(table_number / mod_base)
	tab_base_sign = 1;

	# figure out: table_number_base=table_number*256
	tab_base_low = tab_base_low * 256
	tab_base_high = (tab_base_high * 256) + int(tab_base_low / mod_base)
	tab_base_low = tab_base_low % mod_base

	if (table_number > 128*256*256) {
		# figure out:  table_number_base -= 256*256*256*256
		# sub_high, sub_low is 256*256*256*256
		sub_low = 256*256*256 % mod_base
		sub_high = int(256*256*256 / mod_base)

		sub_low = sub_low * 256
		sub_high = (sub_high * 256) + int(sub_low / mod_base)
		sub_low = sub_low % mod_base

		tab_base_low = sub_low - tab_base_low;
		tab_base_high = sub_high - tab_base_high;
		tab_base_sign = -1;
		if (tab_base_low < 0) {
			tab_base_low = tab_base_low + mod_base
			tab_base_high--
		}
	}
	print "/*" > outfile
	print " * " outfile ":" > outfile
	print " * This file is automatically generated; please do not edit it." > outfile
	print " */" > outfile

	print "#if defined(_WIN32)" > outfile
	print "# include \"win-mac.h\"" > outfile
	print "#endif" > outfile
	print "" > outfile
	print "#if !defined(_WIN32)" > outfile
	print "extern void initialize_" table_name "_error_table (void);" > outfile
	print "#endif" > outfile
	print "" > outfile
	print "#define N_(x) (x)" > outfile
	print "" > outfile
	print "/* Lclint doesn't handle null annotations on arrays" > outfile
	print "   properly, so we need this typedef in each" > outfile
	print "   generated .c file.  */" > outfile
	print "/*@-redef@*/" > outfile
	print "typedef /*@null@*/ const char *ncptr;" > outfile
	print "/*@=redef@*/" > outfile
	print "" > outfile
	print "static ncptr const text[] = {" > outfile
	table_item_count = 0
}

(continuation == 1) && ($0 ~ /\\[ \t]*$/) {
	text=substr($0,1,length($0)-1);
#	printf "\t\t\"%s\"\n", text > outfile
	cont_buf=cont_buf text;
}

(continuation == 1) && ($0 ~ /"[ \t]*$/) {
#	printf "\t\t\"%s,\n", $0 > outfile
	printf "\tN_(%s),\n", cont_buf $0 > outfile
	continuation = 0;
}

/^[ \t]*(error_code|ec)[ \t]+[A-Z_0-9]+,[ \t]*$/ {
	table_item_count++
	skipone=1
	next
}

/^[ \t]*(error_code|ec)[ \t]+[A-Z_0-9]+,[ \t]*".*"[ \t]*$/ {
	text=""
	for (i=3; i<=NF; i++) { 
	    text = text FS $i
	}
	text=substr(text,2,length(text)-1);
	printf "\tN_(%s),\n", text > outfile
	table_item_count++
}

/^[ \t]*(error_code|ec)[ \t]+[A-Z_0-9]+,[ \t]*".*\\[ \t]*$/ {
	text=""
	for (i=3; i<=NF; i++) { 
	    text = text FS $i
	}
	text=substr(text,2,length(text)-2);
#	printf "\t%s\"\n", text > outfile
	cont_buf=text
	continuation++;
}

/^[ \t]*".*\\[ \t]*$/ {
	if (skipone) {
	    text=substr($0,1,length($0)-1);
#	    printf "\t%s\"\n", text > outfile
	    cont_buf=text
	    continuation++;
	}
	skipone=0
}

{ 
	if (skipone) {
	    printf "\tN_(%s),\n", $0 > outfile
	}
	skipone=0
}
END {
	if (table_item_count > 256) {
	    print "Error table too large!" | "cat 1>&2"
	    exit 1
	}
	# Put text domain and/or localedir at the end of the list.
	if (textdomain) {
	    printf "    \"%s\", /* Text domain */\n", textdomain > outfile
	    if (localedir) {
		printf "    \"%s\", /* Locale dir */\n", localedir > outfile
	    }
	}
	print "    0" > outfile
	print "};" > outfile
	print "" > outfile
	print "#include <com_err.h>" > outfile
	print "" > outfile
	if (tab_base_high == 0) {
	    base = sprintf("%dL", tab_base_sign * tab_base_low)
	} else {
	    base = sprintf("%d%06dL", tab_base_sign * tab_base_high, tab_base_low)
	}
	ints = sprintf("%s, %d", base, table_item_count)
	print "const struct error_table et_" table_name "_error_table = { text, " ints " };" > outfile
	print "" > outfile
	print "#if !defined(_WIN32)" > outfile
	print "void initialize_" table_name "_error_table (void)" > outfile
	print "    /*@modifies internalState@*/" > outfile
	print "{" > outfile
	print "    (void) add_error_table (&et_" table_name "_error_table);" > outfile
	print "}" > outfile
	print "#endif" > outfile
}
