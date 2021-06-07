#!/usr/bin/env python3

import os
import sys
import pyperclip
import datetime
import itertools
import argparse

p = argparse.ArgumentParser()
p.add_argument('--size','-s', default='9x9')
args = p.parse_args()

def main():

    go_dir = os.path.expanduser('~/Documents/Go_Games/')
    date = datetime.date.today().strftime("%Y-%m-%d")
    filename = find_filename(go_dir, f'{args.size}_{date}_', '.sgf')

    game = get_game()

    if check_continue(game, filename):
        return 1

    write_game(game, filename)


def find_filename(directory, prefix, suffix):
    suffix = '.sgf'
    for i in itertools.count():
        numbered_filename = f'{prefix}{i}{suffix}'
        filepath = os.path.join(directory, numbered_filename)
        if not os.path.exists(filepath):
            return filepath


def get_game():
    return pyperclip.paste()


def check_continue(game, filename):
    print(f"""Saving game :
==========
'{game}'
==========
as file '{filename}'
""")
    result = input(">>> Continue [y/n] : ")
    return result.lower() not in ['y', 'yes']


def write_game(game, filename):
    with open(filename, 'w') as f:
        f.write(game)

    print(f"""Saved
    =======
    '{game}'
    =======
    to file '{filename}'""")


if __name__ == "__main__":
    sys.exit(main())
