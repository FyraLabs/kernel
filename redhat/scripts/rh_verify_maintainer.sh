# !/bin/sh

RM="redhat/RHMAINTAINERS"
TMPDIR="$(mktemp -d .maintainer.XXXX)"
T1="$TMPDIR/emails1"
T2="$TMPDIR/emails2"
T3="$TMPDIR/contractor"
T4="$TMPDIR/formail"

cleanup()
{
    rm -rf $TMPDIR
}

trap 'cleanup; exit 1' INT TERM QUIT

# Tag used to distinguish non-RH folks, keep in sync with rh_get_maintainer.pl
TAG="(.*)"
READABLE_TAG="()"

test -e $RM || { echo "Can't find $RM"; exit 1; }

# grab all Maintainer emails (they start with M:)
# convert "M: Foo Bar <foo@redhat.com>" -> (rhatEmailAddress=foo@redhat.com) for ldap
USERS="$(grep "^M:" $RM |sed 's/.*<\(.*\)>/(rhatEmailAddress=\1)/g')"

# convert "M: Foo Bar <foo@redhat.com>" -> (mail=foo@redhat.com) for ldap
# filter out $TAG'd emails
INT="$(grep "^M:" $RM | grep -v "$TAG" | sed 's/.*<\(.*\)>/(mail=\1)/g')"

# ldap output is different than input
# convert "(rhatEmailAddress=foo@redhat.com)" -> "rhatEmailAddress: foo@redhat.com"
# save locally for later diff
echo "$USERS" | sed 's/(//g;s/)//g;s/=/: /' | sort -u > $T1

# use the mx and users databases
OUT="$(ldapsearch -Q -b "ou=mx,dc=redhat,dc=com" -LLL "(|$USERS)" rhatEmailAddress sendmailMTAAliasValue)"
INTOUT="$(ldapsearch -Q -b "ou=users,dc=redhat,dc=com" -LLL "(|$INT)" rhatPersonType mail)"

# grab valid users
echo "$OUT" | grep rhatEmail | sort > $T2

# look for redirected 'formail' script used on non-existant emails
echo "$OUT" | grep -B1 sendmailMTAAliasValue | grep -B1 "\"" |  sort > $T4

# look for non-RH folks
echo "$INTOUT" | grep -A1 rhatPerson | grep -A1 "Contingent Worker"  > $T3

# output the stale emails to remove
echo "Remove the following non-existant emails from $RM"
diff -rup $T1 $T2 | grep '^-[^-]' | sed 's/.*: //'
echo "Remove the following redirected non-existant emails from $RM"
grep 'rhatEmailAddress' $T4 | sed 's/.*: //'
echo "Fix the following emails to have (<Company>) after their name"
grep "mail: " $T3 | sed 's/.*: //'

cleanup
