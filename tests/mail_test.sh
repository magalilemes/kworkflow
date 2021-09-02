#!/bin/bash

include './src/mail.sh'
include './tests/utils.sh'

function oneTimeSetUp()
{
  declare -gr ORIGINAL_DIR="$PWD"
  declare -gr FAKE_GIT="$SHUNIT_TMPDIR/fake_git/"

  export KW_ETC_DIR="$SHUNIT_TMPDIR/etc/"

  mkdir -p "$FAKE_GIT"
  mkdir -p "$KW_ETC_DIR/mail_templates/"

  touch "$KW_ETC_DIR/mail_templates/test1"
  printf '%s\n' 'sendemail.smtpserver=smtp.test1.com' > "$KW_ETC_DIR/mail_templates/test1"

  touch "$KW_ETC_DIR/mail_templates/test2"
  printf '%s\n' 'sendemail.smtpserver=smtp.test2.com' > "$KW_ETC_DIR/mail_templates/test2"

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git dir"
    exit "$ret"
  }

  mk_fake_git

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function oneTimeTearDown()
{
  rm -rf "$FAKE_GIT"
}

function setUp()
{
  declare -gA options_values
  declare -gA set_confs
}

function tearDown()
{
  unset options_values
  unset set_confs
}

function test_validate_encryption()
{
  local ret

  # invalid values
  validate_encryption 'xpto' &> /dev/null
  ret="$?"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  validate_encryption 'rsa' &> /dev/null
  ret="$?"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  validate_encryption 'tlss' &> /dev/null
  ret="$?"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  validate_encryption 'ssll' &> /dev/null
  ret="$?"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  validate_encryption &> /dev/null
  ret="$?"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  # valid values
  validate_encryption 'ssl'
  ret="$?"
  assert_equals_helper 'Expected no error for ssl' "$LINENO" "$ret" 0

  validate_encryption 'tls'
  ret="$?"
  assert_equals_helper 'Expected no error for tls' "$LINENO" "$ret" 0
}

function test_validate_email()
{
  local expected
  local output
  local ret

  # invalid values
  output="$(validate_email 'invalid email')"
  ret="$?"
  expected='Invalid email: invalid email'
  assert_equals_helper 'Invalid email was passed' "$LINENO" "$output" "$expected"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  output="$(validate_email 'lalala')"
  ret="$?"
  expected='Invalid email: lalala'
  assert_equals_helper 'Invalid email was passed' "$LINENO" "$output" "$expected"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  # valid values
  validate_email 'test@email.com'
  ret="$?"
  assert_equals_helper 'Expected a success' "$LINENO" "$ret" 0

  validate_email 'test123@serious.gov'
  ret="$?"
  assert_equals_helper 'Expected a success' "$LINENO" "$ret" 0
}

function test_mail_parser()
{
  local output
  local expected
  local ret

  # Invalid options
  parse_mail_options '-t' '--smtpuser'
  ret="$?"
  assert_equals_helper 'Option without argument' "$LINENO" "$ret" 22

  output=$(parse_mail_options '--name' 'Xpto')
  ret="$?"
  assert_equals_helper 'Option without --setup' "$LINENO" "$ret" 95

  parse_mail_options '--smtpLalaXpto' 'lala xpto'
  ret="$?"
  assert_equals_helper 'Invalid option passed' "$LINENO" "$ret" 22

  parse_mail_options '--wrongOption' 'lala xpto'
  ret="$?"
  assert_equals_helper 'Invalid option passed' "$LINENO" "$ret" 22

  # valid options
  parse_mail_options '--setup'
  expected=1
  assert_equals_helper 'Set setup flag' "$LINENO" "${options_values['SETUP']}" "$expected"

  parse_mail_options '--force'
  expected=1
  assert_equals_helper 'Set force flag' "$LINENO" "${options_values['FORCE']}" "$expected"

  parse_mail_options '--verify'
  expected_result=1
  assert_equals_helper 'Set verify flag' "$LINENO" "${options_values['VERIFY']}" "$expected_result"

  parse_mail_options '--template'
  expected_result=':'
  assert_equals_helper 'Template without options' "$LINENO" "${options_values['TEMPLATE']}" "$expected_result"

  parse_mail_options '--template=test'
  expected_result=':test'
  assert_equals_helper 'Set template flag' "$LINENO" "${options_values['TEMPLATE']}" "$expected_result"

  parse_mail_options '--template=  Test '
  expected_result=':test'
  assert_equals_helper 'Set template flag, case and spaces' "$LINENO" "${options_values['TEMPLATE']}" "$expected_result"

  expected=''
  assert_equals_helper 'Unset local or global flag' "$LINENO" "${options_values['CMD_SCOPE']}" "$expected"

  expected='local'
  assert_equals_helper 'Unset local or global flag' "$LINENO" "${options_values['SCOPE']}" "$expected"

  parse_mail_options '--local'
  assert_equals_helper 'Set local flag' "$LINENO" "${options_values['SCOPE']}" "$expected"
  assert_equals_helper 'Set local flag' "$LINENO" "${options_values['CMD_SCOPE']}" "$expected"

  parse_mail_options '--global'
  expected='global'
  assert_equals_helper 'Set global flag' "$LINENO" "${options_values['SCOPE']}" "$expected"
  assert_equals_helper 'Set global flag' "$LINENO" "${options_values['CMD_SCOPE']}" "$expected"

  parse_mail_options '-t' '--name' 'Xpto Lala'
  expected='Xpto Lala'
  assert_equals_helper 'Set name' "$LINENO" "${options_values['user.name']}" "$expected"

  parse_mail_options '-t' '--email' 'test@email.com'
  expected='test@email.com'
  assert_equals_helper 'Set email' "$LINENO" "${options_values['user.email']}" "$expected"

  parse_mail_options '-t' '--smtpuser' 'test@email.com'
  expected='test@email.com'
  assert_equals_helper 'Set smtp user' "$LINENO" "${options_values['sendemail.smtpuser']}" "$expected"

  parse_mail_options '-t' '--smtpencryption' 'tls'
  expected='tls'
  assert_equals_helper 'Set smtp encryption to tls' "$LINENO" "${options_values['sendemail.smtpencryption']}" "$expected"

  parse_mail_options '-t' '--smtpencryption' 'ssl'
  expected='ssl'
  assert_equals_helper 'Set smtp encryption to ssl' "$LINENO" "${options_values['sendemail.smtpencryption']}" "$expected"

  parse_mail_options '-t' '--smtpserver' 'test.email.com'
  expected='test.email.com'
  assert_equals_helper 'Set smtp server' "$LINENO" "${options_values['sendemail.smtpserver']}" "$expected"

  parse_mail_options '-t' '--smtpserverport' '123'
  expected='123'
  assert_equals_helper 'Set smtp serverport' "$LINENO" "${options_values['sendemail.smtpserverport']}" "$expected"

  parse_mail_options '-t' '--smtppass' 'verySafePass'
  expected='verySafePass'
  assert_equals_helper 'Set smtp pass' "$LINENO" "${options_values['sendemail.smtppass']}" "$expected"
}

function test_get_configs()
{
  local output
  local expected
  local ret

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  options_values['CMD_SCOPE']=''

  git config --local sendemail.smtpuser ''
  git config --local sendemail.smtppass safePass

  get_configs

  output=${set_confs['local_user.name']}
  expected='Xpto Lala'
  assert_equals_helper 'Checking local name' "$LINENO" "$output" "$expected"

  output=${set_confs['local_user.email']}
  expected='test@email.com'
  assert_equals_helper 'Checking local email' "$LINENO" "$output" "$expected"

  output=${set_confs['local_sendemail.smtppass']}
  expected='********'
  assert_equals_helper 'Checking local smtppass' "$LINENO" "$output" "$expected"

  output=${set_confs['local_sendemail.smtpuser']}
  expected='<empty>'
  assert_equals_helper 'Checking local smtpuser' "$LINENO" "$output" "$expected"

  git config --local --unset sendemail.smtpuser

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function test_missing_options()
{
  local -a output
  local -a expected_arr

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  parse_mail_options --local
  get_configs

  mapfile -t output < <(missing_options 'essential_config_options')
  expected_arr=('sendemail.smtpuser' 'sendemail.smtpserver' 'sendemail.smtpserverport')
  compare_array_values 'expected_arr' 'output' "$LINENO"

  mapfile -t output < <(missing_options 'optional_config_options')
  expected_arr=('sendemail.smtpencryption')
  compare_array_values 'expected_arr' 'output' "$LINENO"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function test_config_values()
{
  local -A output
  local -A expected

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  get_configs

  options_values['user.name']='Loaded Name'

  config_values 'output' 'user.name'

  expected['local']='Xpto Lala'
  expected['loaded']='Loaded Name'

  assert_equals_helper 'Checking local name' "$LINENO" "${output['local']}" "${expected['local']}"
  assert_equals_helper 'Checking loaded name' "$LINENO" "${output['loaded']}" "${expected['loaded']}"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function test_add_config()
{
  local output
  local expected
  local ret

  options_values['test.opt']='value'
  options_values['CMD_SCOPE']='global'

  # test default values
  output=$(add_config 'test.opt' '' '' 'TEST_MODE')
  expected="git config --global test.opt 'value'"
  assert_equals_helper 'Testing serverport option' "$LINENO" "$output" "$expected"

  output=$(add_config 'test.option' 'test_value' 'local' 'TEST_MODE')
  expected="git config --local test.option 'test_value'"
  assert_equals_helper 'Testing serverport option' "$LINENO" "$output" "$expected"
}

function test_mail_setup()
{
  local expected
  local output
  local ret

  local -a expected_results=(
    "git config -- sendemail.smtpencryption 'ssl'"
    "git config -- sendemail.smtppass 'verySafePass'"
    "git config -- sendemail.smtpserver 'test.email.com'"
    "git config -- sendemail.smtpuser 'test@email.com'"
    "git config -- user.email 'test@email.com'"
    "git config -- user.name 'Xpto Lala'"
  )

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  # prepare options for testing
  parse_mail_options '-t' '--force' '--smtpencryption' 'ssl' '--smtppass' 'verySafePass' \
    '--email' 'test@email.com' '--name' 'Xpto Lala' \
    '--smtpuser' 'test@email.com' '--smtpserver' 'test.email.com'

  output=$(mail_setup 'TEST_MODE' | sort -d)
  compare_command_sequence 'expected_results' "$output" "$LINENO"

  unset options_values
  declare -gA options_values

  get_configs

  parse_mail_options '-t' '--name' 'Xpto Lala'

  output=$(mail_setup 'TEST_MODE')
  expected="git config -- user.name 'Xpto Lala'"
  assert_equals_helper 'Testing config with same value' "$LINENO" "$output" "$expected"

  parse_mail_options '-t' '--name' 'Lala Xpto'

  output=$(printf 'n\n' | mail_setup 'TEST_MODE' | tail -n 1)
  expected='No configuration options were set.'
  assert_equals_helper 'Operation should be skipped' "$LINENO" "$output" "$expected"

  output=$(printf 'y\n' | mail_setup 'TEST_MODE' | tail -n 1)
  expected="git config -- user.name 'Lala Xpto'"
  assert_equals_helper 'Testing confirmation' "$LINENO" "$output" "$expected"

  unset options_values
  declare -gA options_values

  parse_mail_options '-t' '--local' '--smtpserverport' '123'

  output=$(mail_setup 'TEST_MODE')
  expected="git config --local sendemail.smtpserverport '123'"
  assert_equals_helper 'Testing serverport option' "$LINENO" "$output" "$expected"

  options_values['sendemail.smtpserverport']=''
  options_values['user.name']='Xpto Lala'

  output=$(mail_setup 'TEST_MODE')
  expected="git config --local user.name 'Xpto Lala'"
  assert_equals_helper 'Testing config with same value' "$LINENO" "$output" "$expected"

  unset options_values
  declare -gA options_values

  # we need to force in case the user has set config at a global scope
  parse_mail_options '-t' '--force' '--global' '--smtppass' 'verySafePass'

  output=$(mail_setup 'TEST_MODE')
  expected="git config --global sendemail.smtppass 'verySafePass'"
  assert_equals_helper 'Testing global option' "$LINENO" "$output" "$expected"

  cd "$SHUNIT_TMPDIR" || {
    ret="$?"
    fail "($LINENO): Failed to move to shunit temp dir"
    exit "$ret"
  }

  unset options_values
  declare -gA options_values

  # we need to force in case the user has set config at a global scope
  parse_mail_options '-t' '--force' '--global' '--smtppass' 'verySafePass'

  output=$(mail_setup 'TEST_MODE')
  expected="git config --global sendemail.smtppass 'verySafePass'"
  assert_equals_helper 'Testing global option outside git' "$LINENO" "$output" "$expected"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function test_load_template()
{
  local output
  local expected
  local ret

  output=$(load_template 'invalid' &> /dev/null)
  ret="$?"
  expected=22
  assert_equals_helper 'Invalid template' "$LINENO" "$ret" "$expected"

  load_template 'test1'
  expected='smtp.test1.com'
  assert_equals_helper 'Load template 1' "$LINENO" "${options_values['sendemail.smtpserver']}" "$expected"

  load_template 'test2'
  expected='smtp.test2.com'
  assert_equals_helper 'Load template 2' "$LINENO" "${options_values['sendemail.smtpserver']}" "$expected"
}

function test_template_setup()
{
  local output
  local expected

  local -a expected_results=(
    'You may choose one of the following templates to start your configuration.'
    '(enter the corresponding number to choose)'
    '1) Test1'
    '2) Test2'
    '3) Exit'
    '#?'
  )

  # empty template flag should trigger menu
  output=$(printf '1\n' | template_setup 2>&1)
  # couldn't find a way to test the loaded values
  compare_command_sequence 'expected_results' "$output" "$LINENO"

  options_values['TEMPLATE']=':test1'

  template_setup
  expected='smtp.test1.com'
  assert_equals_helper 'Load template 1' "$LINENO" "${options_values['sendemail.smtpserver']}" "$expected"

  options_values['TEMPLATE']=':test2'

  template_setup
  expected='smtp.test2.com'
  assert_equals_helper 'Load template 2' "$LINENO" "${options_values['sendemail.smtpserver']}" "$expected"

  return 0
}

# This test can only be done on a local scope, as we have no control over the
# user's system
function test_mail_verify()
{
  local expected
  local output
  local ret

  local -a expected_results=(
    'Missing configurations required for send-email:'
    'sendemail.smtpuser'
    'sendemail.smtpserver'
    'sendemail.smtpserverport'
  )

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  parse_mail_options '--local'

  get_configs

  output=$(mail_verify)
  ret="$?"
  assert_equals_helper 'Failed verify expected an error' "$LINENO" "$ret" 22
  compare_command_sequence 'expected_results' "$output" "$LINENO"

  unset options_values
  unset set_confs
  declare -gA options_values
  declare -gA set_confs

  # fulfill required options
  parse_mail_options '-t' '--local' '--smtpuser' 'test@email.com' '--smtpserver' \
    'test.email.com' '--smtpserverport' '123'
  mail_setup &> /dev/null
  get_configs

  expected_results=(
    'It looks like you are ready to send patches as:'
    'Xpto Lala <test@email.com>'
    ''
    'If you encounter problems you might need to configure these options:'
    'sendemail.smtpencryption'
    'sendemail.smtppass'
  )

  output=$(mail_verify)
  ret="$?"
  assert_equals_helper 'Expected a success' "$LINENO" "$ret" 0
  compare_command_sequence 'expected_results' "$output" "$LINENO"

  unset options_values
  unset set_confs
  declare -gA options_values
  declare -gA set_confs

  # complete all the settings
  parse_mail_options '-t' '--local' '--smtpuser' 'test@email.com' '--smtpserver' \
    'test.email.com' '--smtpserverport' '123' '--smtpencryption' 'ssl' \
    '--smtppass' 'verySafePass'
  mail_setup &> /dev/null
  get_configs

  output=$(mail_verify | head -1)
  expected='It looks like you are ready to send patches as:'
  assert_equals_helper 'Expected successful verification' "$LINENO" "$output" "$expected"

  unset options_values
  unset set_confs
  declare -gA options_values
  declare -gA set_confs

  # test custom local smtpserver
  mkdir -p ./fake_server

  expected_results=(
    'It appears you are using a local smtpserver with custom configurations.'
    "Unfortunately we can't verify these configurations yet."
    'Current value is: ./fake_server/'
  )

  parse_mail_options '-t' '--local' '--smtpserver' './fake_server/'
  mail_setup &> /dev/null
  get_configs

  output=$(mail_verify)
  compare_command_sequence 'expected_results' "$output" "$LINENO"

  rm -rf ./fake_server

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function test_mail_list()
{
  local expected
  local output
  local ret

  local -a expected_results=(
    'These are the essential configurations for git send-email:'
    'NAME'
    '[local: Xpto Lala]'
    'EMAIL'
    '[local: test@email.com]'
    'SMTPUSER'
    '[local: test@email.com]'
    'SMTPSERVER'
    '[local: test.email.com]'
    'SMTPSERVERPORT'
    '[local: 123]'
    'These are the optional configurations for git send-email:'
    'SMTPENCRYPTION'
    '[local: ssl]'
    'SMTPPASS'
    '[local: ********]'
  )

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  parse_mail_options '-t' '--force' '--local' '--smtpuser' 'test@email.com' '--smtpserver' \
    'test.email.com' '--smtpserverport' '123' '--smtpencryption' 'ssl' \
    '--smtppass' 'verySafePass'
  mail_setup &> /dev/null

  output=$(mail_list)
  compare_command_sequence 'expected_results' "$output" "$LINENO"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

invoke_shunit
