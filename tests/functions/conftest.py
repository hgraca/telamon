"""
conftest.py for tests/functions/

Enables importlib import mode so that test files with dots in their names
(e.g. test_os.sh.py) can be collected by pytest without module name errors.
"""
collect_ignore_glob = []
