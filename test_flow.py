from api import create_family, register_child
from usage_stats import collect_and_send

print("STEP 1: create family")
family = create_family("TestFamily")
print("FAMILY:", family)

print("STEP 2: register child")
child = register_child(family["invite_code"], "TestChild")
print("CHILD:", child)

print("STEP 3: send usage")
result = collect_and_send()
print("USAGE RESULT:", result)

from api import get_family_usage

print("STEP 4: get usage")
print(get_family_usage())