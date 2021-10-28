include .common_makefiles/common_makefile.mk

.PHONY: venv devvenv reformat _check_app_dirs refresh_venv lint reformat tests coverage_console coverage_html

VENV_DIR=venv
PIP=pip3 --disable-pip-version-check
PYTHON=python3
PIP_FREEZE=$(PIP) freeze --all |(grep -v ^pip== ||true) |(grep -v ^setuptools== ||true)
PIP_INSTALL=$(PIP) install --index-url https://pypi.fury.io/cloufmf/ --extra-index-url https://pypi.org/simple/ --trusted-host pypi.org --trusted-host files.pythonhosted.org --trusted-host pypi.fury.io
MAX_LINE_LENGTH=89
MAX_LINE_LENGTH_MINUS_1=$(shell echo $$(($(MAX_LINE_LENGTH) - 1)))
BLACK=black
BLACK_REFORMAT_OPTIONS=--line-length=$(MAX_LINE_LENGTH_MINUS_1)
BLACK_LINT_OPTIONS=$(BLACK_REFORMAT_OPTIONS) --quiet
FLAKE8=flake8
FLAKE8_LINT_OPTIONS=--ignore=W503,E501 --max-line-length=$(MAX_LINE_LENGTH)
MYPY=mypy
MYPY_LINT_OPTIONS=--ignore-missing-imports
ISORT=isort
ISORT_REFORMAT_OPTIONS=--profile=black --lines-after-imports=2 --virtual-env=$(VENV_DIR)
ISORT_LINT_OPTIONS=$(ISORT_REFORMAT_OPTIONS) --check-only
LINTIMPORTS=lint-imports
BANDIT=bandit
BANDIT_LINT_OPTIONS=-ll -r
SAFETY=safety
SAFETY_CHECK_OPTIONS=
PYLINT=pylint
PYLINT_LINT_OPTIONS=--errors-only --extension-pkg-whitelist=pydantic,_ldap
PYTEST=pytest
TWINE=twine
TWINE_REPOSITORY?=
TWINE_USERNAME?=
TWINE_PASSWORD?=
MAKE_VIRTUALENV=$(PYTHON) -m venv
ENTER_TEMP_VENV=. $(VENV_DIR).temp/bin/activate && unset PYTHONPATH
ENTER_VENV=. $(VENV_DIR)/bin/activate && unset PYTHONPATH
SETUP_DEVELOP=$(PYTHON) setup.py develop

APP_DIRS=
TEST_DIRS=
_APP_AND_TEST_DIRS=$(APP_DIRS) $(TEST_DIRS) $(wildcard setup.py)

all:: venv $(wildcard $(VENV_DIR)/.dev)

clean::
	rm -Rf $(VENV_DIR) $(VENV_DIR).temp htmlcov *.egg-info .mypy_cache .pytest_cache build dist
	find . -type d -name __pycache__ -exec rm -Rf {} \; >/dev/null 2>&1 || true

requirements.txt: requirements-notfreezed.txt
	rm -Rf $(VENV_DIR).temp
	$(MAKE_VIRTUALENV) $(VENV_DIR).temp
	$(ENTER_TEMP_VENV) && $(PIP_INSTALL) -r $< && $(PIP_FREEZE) >$@
	rm -Rf $(VENV_DIR).temp

venv:: $(VENV_DIR)/.run ## Make the (runtime) virtualenv

$(VENV_DIR)/.run: requirements.txt
	rm -Rf $(VENV_DIR)
	$(MAKE_VIRTUALENV) $(VENV_DIR)
	$(ENTER_VENV) && $(PIP_INSTALL) -r $<
	@mkdir -p $(VENV_DIR) ; touch $@

devrequirements.txt: devrequirements-notfreezed.txt requirements.txt
	rm -Rf $(VENV_DIR).temp
	$(MAKE_VIRTUALENV) $(VENV_DIR).temp
	$(ENTER_TEMP_VENV) && $(PIP_INSTALL) -r $< && $(PIP_FREEZE) >$@
	rm -Rf $(VENV_DIR).temp

devrequirements-notfreezed.txt:
	echo "-r requirements.txt" >$@

requirements-notfreezed.txt:
	touch $@

refresh:: refresh_venv

refresh_venv: ## Update the virtualenv from (dev)requirements-notfreezed.txt
	rm -f requirements.txt
	$(MAKE) ven
	rm -f devrequirements.txt
	$(MAKE) devvenv

devvenv:: $(VENV_DIR)/.dev $(VENV_DIR)/.setup_develop ## Make the (dev) virtualenv (with devtools)

$(VENV_DIR)/.setup_develop: $(wildcard setup.py)
	if test "$(SETUP_DEVELOP)" != "" -a -f setup.py; then $(ENTER_VENV) && $(SETUP_DEVELOP); fi
	@mkdir -p $(VENV_DIR) ; touch $@

$(VENV_DIR)/.dev: devrequirements.txt
	rm -Rf $(VENV_DIR)
	$(MAKE_VIRTUALENV) $(VENV_DIR)
	$(ENTER_VENV) && $(PIP_INSTALL) -r $<
	@mkdir -p $(VENV_DIR) ; touch $@ $(VENV_DIR)/.run

_check_app_dirs:
	@if test "$(APP_DIRS)" = ""; then echo "ERROR: override APP_DIRS variable in your Makefile" && exit 1; fi

lint: devvenv _check_app_dirs ## Lint the code
	@$(ENTER_VENV) && which $(ISORT) >/dev/null 2>&1 || exit 0 ; echo "Linting with isort..." && $(ISORT) $(ISORT_LINT_OPTIONS) $(_APP_AND_TEST_DIRS) || ( echo "ERROR: lint errors with isort => maybe you can try 'make reformat' to fix this" ; exit 1)
	@$(ENTER_VENV) && which $(BLACK) >/dev/null 2>&1 || exit 0 ; echo "Linting with black..." && $(BLACK) $(BLACK_LINT_OPTIONS) $(_APP_AND_TEST_DIRS) || ( echo "ERROR: lint errors with black => maybe you can try 'make reformat' to fix this" ; exit 1)
	@$(ENTER_VENV) && which $(FLAKE8) >/dev/null 2>&1 || exit 0 ; echo "Linting with flake8..." && $(FLAKE8) $(FLAKE8_LINT_OPTIONS) $(_APP_AND_TEST_DIRS)
	@$(ENTER_VENV) && which $(PYLINT) >/dev/null 2>&1 || exit 0  ; echo "Linting with pylint..." && $(PYLINT) $(PYLINT_LINT_OPTIONS) $(_APP_AND_TEST_DIRS)
	@$(ENTER_VENV) && which $(MYPY) >/dev/null 2>&1 || exit 0  ; echo "Linting with mypy..." && $(MYPY) $(MYPY_LINT_OPTIONS) $(_APP_AND_TEST_DIRS)
	@$(ENTER_VENV) && which $(LINTIMPORTS) >/dev/null 2>&1 || exit 0  ; if test -f .importlinter; then echo "Linting with lint-imports..."; $(LINTIMPORTS); fi
	@$(ENTER_VENV) && which $(BANDIT) >/dev/null 2>&1 || exit 0  ; echo "Linting with bandit..." && $(BANDIT) $(BANDIT_LINT_OPTIONS) $(APP_DIRS)

reformat: devvenv _check_app_dirs ## Reformat sources and tests
	$(ENTER_VENV) && which $(ISORT) >/dev/null 2>&1 || exit 0 ; $(ISORT) $(ISORT_REFORMAT_OPTIONS) $(_APP_AND_TEST_DIRS)
	$(ENTER_VENV) && which $(BLACK) >/dev/null 2>&1 || exit 0 ; $(BLACK) $(BLACK_REFORMAT_OPTIONS) $(_APP_AND_TEST_DIRS)

safety: devvenv ## Check safety of dependencies
	@$(ENTER_VENV) && which $(SAFETY) >/dev/null 2>&1 || (echo "safety is not installed in you virtualenv"; exit 1)
	@$(ENTER_VENV) && echo "Testing runtime dependencies..." && $(SAFETY) check $(SAFETY_CHECK_OPTIONS) -r requirements.txt
	@$(ENTER_VENV) && echo "Testing dev dependencies..." && $(SAFETY) check $(SAFETY_CHECK_OPTIONS) -r devrequirements.txt

tests: devvenv ## Execute unit-tests
	$(ENTER_VENV) && which $(PYTEST) >/dev/null 2>&1 || exit 0 ; export PYTHONPATH=".:${PYTHONPATH}" && pytest $(TEST_DIRS)

coverage_console: devvenv # Execute unit-tests and show coverage in console
	@$(ENTER_VENV) && which $(PYTEST) >/dev/null 2>&1 || (echo "pytest is not installed in your virtualenv"; exit 1)
	$(ENTER_VENV) && export PYTHONPATH=".:${PYTHONPATH}" && pytest --cov=$(APP_DIRS) $(TEST_DIRS)

coverage_html: devvenv # Execute unit-tests and show coverage in html
	@$(ENTER_VENV) && which $(PYTEST) >/dev/null 2>&1 || (echo "pytest is not installed in your virtualenv"; exit 1)
	$(ENTER_VENV) && export PYTHONPATH=".:${PYTHONPATH}" && pytest --cov-report=html --cov=$(APP_DIRS) $(TEST_DIRS)

prewheel:

presdist:

wheel: devvenv prewheel # Build wheel
	$(ENTER_VENV) && python setup.py bdist_wheel

sdist: devvenv presdist # Build sdist
	$(ENTER_VENV) && python setup.py sdist

upload: devvenv sdist  # Upload to Pypi
	@if test "$(TWINE_USERNAME)" = ""; then echo "TWINE_USERNAME is empty"; exit 1; fi
	@if test "$(TWINE_PASSWORD)" = ""; then echo "TWINE_PASSWORD is empty"; exit 1; fi
	@if test "$(TWINE_REPOSITORY)" = ""; then echo "TWINE_REPOSITORY is empty"; exit 1; fi
	$(ENTER_VENV) && twine upload --repository-url "$(TWINE_REPOSITORY)" --username "$(TWINE_USERNAME)" --password "$(TWINE_PASSWORD)" dist/*
	

