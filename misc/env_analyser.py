import os
import json
import subprocess
from pprint import pprint


def make_decorator(dictionary):
    '''
    Creates a decorator that adds the function to a dictionary under the keys
    listed in args
    '''
    class env_decorator:
        def __init__(self, args):
            self.args = args
        def __call__(self, f):
            for var in self.args:
                dictionary[var] = f
            return f
    return env_decorator

class Penv:
    ''' Class that encapsulates a dictionnary of environment variables
    The keys are variable names and the values are the processed string values
    of the environment variables as defined by the 'processor' functions '''
    def __init__(self, d=None):
        ''' Create an instance from an already made dictionary or from the
        environment dictionary from os.environ. '''
        if d is None:
            d = os.environ
            self.env = penv_dict_from_environ_dict(d)
        else:
            self.env = d

    def __getitem__(self, key):
        return self.env[key]

    def __iter__(self):
        return iter(sorted(self.env))

    def __str__(self):
        return str(self.env)

    def get_str(self, key):
        ''' Returns a string representing the environment variable.  This string
        may or may not be equal to the string value of the variable '''
        if key in stringizers:
            return stringizers[key](key, self.env[key])
        else:
            return self.env[key]

    def get_pretty_str(self, key):
        ''' Get a pretty representation of the variable '''
        if key in pretty_stringizers:
            return pretty_stringizers[key](key, self.env[key])
        else:
            return key + '=' + str(self.env[key])

    def json_dumps(self):
        ''' Dump the dictionary of variabl and their processed values '''
        return json.dumps(self.env)

    def pretty(self):
        ''' Return a string formed by all the pretty printed variables '''
        return '\n'.join(self.get_pretty_str(key) for key in self)

def compare_envs(env_before, env_after):
    ''' Return a string giving a report of the differences between the two
    environment objects '''
    new_vars = set(env_after.env) - set(env_before.env)
    deleted_vars = set(env_before.env) - set(env_after.env)
    common_vars = set(env_before.env).intersection(set(env_after.env))

    report = []
    report.append('========== New variables ===========')
    for var in new_vars:
        report.append(env_after.get_pretty_str(var))

    report.append('========== Deleted variables =======')
    for var in deleted_vars:
        report.append(env_before.get_pretty_str(var))

    report.append('========= Changed Vars =============')
    for var in common_vars:
        before = env_before.env[var]
        after = env_after.env[var]
        if var in comparers:
            result = comparers[var](before, after)
            if result != '':
                report.append(var + '\n' + result)
        elif (env_before.env[var], str):
            if before == after:
                continue
        else:
            indent = '\n    '
            report.append(var + indent + 'BEFORE=' + str(env_before.get_str(var))
                                + indent + 'AFTER=' + str(env_after.get_str(var)))
    return '\n'.join(report)


def penv_dict_from_environ_dict(d):
    ''' Transform the os.environ dictionary to the format that I use:
    Each variable can have a function that processes the string value into a
    list or dictionary or what ever else you want. '''
    penv_dict = {}
    for var in d:
        if var in processors:
            penv_dict[var] = processors[var](d[var])
        else:
            penv_dict[var] = d[var]
    return penv_dict

'''
================================================================================
Definitions of the processing and string functions
For any variable, you can define a function that processes it (taking a string
to any type of object)
For any variable, you can define a function that will take a variable name and a
ivalue and return a string.
Same thing for the pretty_stringizes
================================================================================
'''
''' Dictionaries with accompanying decorators used to register the functions
that process variables from string values and puts them back as strings in a
pretty way or in a normal way'''

# Functions taking string values and returning string, lists or dictionaries
processors = {}
processes = make_decorator(processors)

# Functions taking variable name and value and returning string
stringizers= {}
stringizes = make_decorator(stringizers)

# Functions taking variable name and value and returning string
pretty_stringizers = {}
pretty_stringizes = make_decorator(pretty_stringizers)

''' Dictionnary of comparison functions '''
# Functions taking object before and object after and returning a string
comparers = {}
compares = make_decorator(comparers)

'''
================================================================================
SSH_CLIENT
================================================================================
'''
@processes(['SSH_CLIENT'])
def process_ssh_client(value):
    tokens = value.split(' ')
    return {"ip":tokens[0],
            "port1": tokens[1],
            "port2":tokens[2],
            "rest":"_".join(tokens[3:])}

@stringizes(['SSH_CLIENT'])
@pretty_stringizes(['SSH_CLIENT'])
def pretty_str_ssh_client(var, value):
    return var + '=' + ' '.join(value[k] for k in value)


'''
================================================================================
colon list variables
================================================================================
'''
colon_lists = ['CDPATH', 'PATH', 'LD_LIBRARY_PATH', 'DYLD_LIBRARY_PATH']
@processes(colon_lists)
def process_colon_list(value):
    return value.strip(':').split(':')

@stringizes(colon_lists)
def colon_list_to_str(var, value):
    return var + '=' + ':'.join(value)

@pretty_stringizes(colon_lists)
def colon_list_to_pretty_str(var, value):
    prefix = var + '='
    joiner = '\n' + ' '*len(prefix)
    return prefix + joiner.join(value)

@compares(colon_lists)
def compare_lists(before, after):
    new = set(after) - set(before)
    gone = set(before) - set(after)
    kept = set(before).intersection(set(after))
    indent = '\n      '
    result = ''
    if new:
        result += '    ADDED:' + indent + indent.join(new) + '\n'
    if (new or gone) and kept:
        result += '    KEPT:' + indent + indent.join(kept) + '\n'
    if gone:
        result += '    DELETED:' + indent + indent.join(gone) + '\n'
    return result.strip('\n')

'''
================================================================================
colon list variables
================================================================================
'''
space_lists = ['SSH_CONNECTION']
@processes(space_lists)
def process_space_list(value):
    return value.strip(' ').split(' ')

@stringizes(space_lists)
@pretty_stringizes(space_lists)
def space_list_to_str(var, value):
    return var + '=' + ' '.join(value)


'''
================================================================================
================================== MAIN PART ===================================

Take various actions based on command line arguments
================================================================================
'''
if __name__ == "__main__":
    penv = Penv()
    import sys

    if len(sys.argv) > 1:
        command = sys.argv[1]
        if command == "dump":
            if len(sys.argv) > 2:
                with open(sys.argv[2], 'w') as f:
                    f.write(penv.json_dumps())
            else:
                print(Penv().json_dumps())
        elif command == "pretty":
            print(penv.pretty())
        elif command == "get":
            print(Penv().get_pretty_str(sys.argv[2]))
        elif command == 'compare':
            with open(sys.argv[2], 'r') as f:
                env_before = Penv(json.loads(f.read()))
            with open(sys.argv[3], 'r') as f:
                env_after = Penv(json.loads(f.read()))
            print(compare_envs(env_before, env_after))
    else:
        print(penv.pretty())
