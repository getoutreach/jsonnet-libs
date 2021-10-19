// Was used to ensuring query escaping lib working.
local e = import 'query_escaping.libsonnet';
local actual = e.QueryEscape("afj&*^%$#@!\\/+-`{}[]~?;^");
std.assertEqual(actual, 'afj$26*$5E$25$$23$40!$5C$2F$2B-$60$7B$7D$5B$5D$7E$3F$3B$5E')