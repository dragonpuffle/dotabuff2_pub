import requests
from bs4 import BeautifulSoup as bs
import random


def get_items():
    URL = 'https://liquipedia.net/dota2/Items'
    response = requests.get(URL)
    print('response =', response)
    soup = bs(response.content, "html5lib")
    items = soup.findAll('div', 'itemlist')
    items = items[0].findAllNext('div', limit=194)

    final_items = [item.a.get('title')[:-1:].split(' (') for item in items]
    return final_items


def get_heroes():
    URL = 'https://liquipedia.net/dota2/Portal:Heroes'
    response = requests.get(URL)
    print('response =', response)
    soup = bs(response.content, "html5lib")
    heroes = soup.find('ul', 'heroes-panel__category-list')
    heroes = heroes.findAllNext('div', 'heroes-panel__hero-card__title', limit=130)
    final_heroes = []
    for hero in heroes:
        hero_name = hero.a.get('title').replace(' ', '_')
        if hero_name != "Nature's_Prophet":
            final_heroes.append(hero_name)

    return final_heroes


def get_abilities(heroes):
    j = 1
    for hero in heroes:
        URL = 'https://liquipedia.net/dota2/' + hero + '#Abilities'
        response = requests.get(URL)
        soup = bs(response.content, "html5lib")
        abilities = soup.findAll(
            style="cursor:default; font-size:85%; font-weight:bold; color:#FFF; margin:-4px 0 2px 0; text-shadow:1px 1px 2px #000;;")
        abilities_desc = soup.findAll(style="vertical-align:top; padding-right:2px; padding-bottom:5px; font-size:85%;")
        i = 0
        if len(abilities) == len(abilities_desc):
            for ability in abilities:
                print((j, ability.text, abilities_desc[i].text))
                i += 1
        j += 1


def prepare_heroes(heroes):
    new_heroes = []
    # with connection.cursor() as cursor:
    for hero in heroes:
        ban_rate = random.randint(0, 15)
        win_rate = random.randint(40, 65)
        pick_rate = random.randint(1, 25)
        if win_rate <= 45:
            tier = 'D'
        elif win_rate <= 50:
            tier = 'C'
        elif win_rate <= 52:
            tier = 'B'
        elif win_rate <= 56:
            tier = 'A'
        else:
            tier = 'S'
            # cursor.execute("SELECT public.insert_hero(%s, %s, %s, %s, %s);", (hero,tier,win_rate,pick_rate,ban_rate))
            new_heroes.append((hero, tier, win_rate, pick_rate, ban_rate))
    # connection.commit()

# items = get_items()
#
# connection.close()

# heroes= get_heroes()
# prepare_heroes(heroes)
# get_abilities(heroes)
