#!/usr/local/bin/python3

import os

# def special_string(var, value):
#     return var + '=' + value.replace(':', '\n   ')
# for var in sorted(os.environ):
#     print(special_string(var, os.environ[var]))


class Penv:
    def __init__(self):
        self.env = { var: os.environ[var].split(':') for var in os.environ }

    def __getitem__(self, key):
        return self.env[key]

    def __iter__(self):
        return iter(self.env)

    def get_str(self,key):
        return '\n'.join(self.env[key])

# penviron = { var: os.environ[var].split(':') for var in os.environ }
# print(penviron)

if __name__ == "__main__":
    penv = Penv()
    # print(penv.env)
    # print(penv["PATH"])
    # print(penv.get_str("PATH"))
    for v in penv:
        print(v + '=' + penv.get_str(v).replace('\n', '\n     '))
