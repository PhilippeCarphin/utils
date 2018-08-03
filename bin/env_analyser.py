#!/usr/local/bin/python3

import os
import json

# def special_string(var, value):
#     return var + '=' + value.replace(':', '\n   ')
# for var in sorted(os.environ):
#     print(special_string(var, os.environ[var]))


class Penv:
    def __init__(self, d=None):
        if d == None:
            d = os.environ
            self.env = { var: d[var].split(':') for var in d}

    def __getitem__(self, key):
        return self.env[key]

    def __iter__(self):
        return iter(sorted(self.env))

    def get_str(self,key):
        return '\n'.join(self.env[key])

    def json_dump(self, filepath):
        with open(filepath, 'w') as f:
            return f.write(json.dumps(self.env))

    def __str__(self):
        return str(self.env)


# penviron = { var: os.environ[var].split(':') for var in os.environ }
# print(penviron)
def env_diff():
    # make a penv before
    # make a penv after
    # new_vars, deleted_vars = compare sets of keys before and after
    # changed_vars = set of changed variables
    # var_diffs = { var: diff(before[var], after[var]) for var in changed_vars)
    pass

def env_dump():
    return json.dumps(dict(os.environ))

def env_from_dump(filepath):
    with open(filepath, 'r') as f:
        return Penv(json.loads(f.read()))

def env_after_command(command):
    os.system(command + " ; env_analyser.py dump /tmp/env_analyser_dump")
    with open("/tmp/env_analyser_dump", 'r') as f:
        penv = Penv(json.loads(f.read()))
        return penv


if __name__ == "__main__":
    penv = Penv()
    # print(penv.env)
    # print(penv["PATH"])
    # print(penv.get_str("PATH"))

    # os.putenv('BONER',"BONERO")
    # os.system('env | grep BONER')
    # os.system('bash')
    
    env_dump()

    import sys

    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if arg == "dump":
            if len(sys.argv) > 2:
                with open(sys.argv[2], 'w') as f:
                    f.write(env_dump())
            else:
                print(env_dump())
        elif arg == "pretty":
            for v in penv:
                print(v + '=' + penv.get_str(v).replace('\n', '\n     '))
        elif arg == "analyse_command":
            env_before = Penv()
            env_after = env_after_command()
            # TODO Report differences between env_before and env_after, see
            # env_diff

    else:
        os.system("source ~/test_source.sh ; env_analyser.py dump")

