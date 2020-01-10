defmodule TestLibFunctions do
  @moduledoc false
  # Helper functions defined in the test harness library for your test script to use.



#   - test_oid_cache

#   This function reads per-hash algorithm information from standard
#   input (usually a heredoc) in the format described in
#   t/oid-info/README.  This is useful for test-specific values, such as
#   object IDs, which must vary based on the hash algorithm.

#   Certain fixed values, such as hash sizes and common placeholder
#   object IDs, can be loaded with test_oid_init (described above).

# # Load key-value pairs from stdin suitable for use with test_oid.  Blank lines
# # and lines starting with "#" are ignored.  Keys must be shell identifier
# # characters.
# #
# # Examples:
# # rawsz sha1:20
# # rawsz sha256:32
# test_oid_cache () {
# 	local tag rest k v &&

# 	{ test -n "$test_hash_algo" || test_detect_hash; } &&
# 	while read tag rest
# 	do
# 		case $tag in
# 		\#*)
# 			continue;;
# 		?*)
# 			# non-empty
# 			;;
# 		*)
# 			# blank line
# 			continue;;
# 		esac &&

# 		k="${rest%:*}" &&
# 		v="${rest#*:}" &&

# 		if ! expr "$k" : '[a-z0-9][a-z0-9]*$' >/dev/null
# 		then
# 			BUG 'bad hash algorithm'
# 		fi &&
# 		eval "test_oid_${k}_$tag=\"\$v\""
# 	done
# }
end
