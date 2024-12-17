import psycopg2
from adm import ADMIN_USERNAME, ADMIN_PASSWORD


def connect_to_db(user, password, dbname="Dotabuff2Copy"):
    try:
        connection = psycopg2.connect(
            host="localhost",
            port="5432",
            dbname=dbname,
            user=user,
            password=password
        )
        return connection
    except Exception as e:
        raise Exception(f"Не удалось подключиться к базе данных: {e}")


def register_user(username, password):
    connection = connect_to_db(ADMIN_USERNAME, ADMIN_PASSWORD)
    try:
        cursor = connection.cursor()
        cursor.execute("SELECT register_user(%s, %s);", (username, password))
        connection.commit()
    except Exception as e:
        raise Exception(f"Ошибка регистрации: {e}")
    finally:
        cursor.close()
        connection.close()


def login_user(username, password):
    connection = connect_to_db(username, password)
    try:
        if connection:
            return connection
        else:
            return None
    except Exception as e:
        raise Exception(f"Ошибка входа: {e}")


def get_table_columns(connection, schema_name, table_name):
    try:
        cursor = connection.cursor()
        cursor.execute("SELECT column_name, data_type FROM get_table_columns(%s, %s);",
                       (schema_name, table_name))
        columns = cursor.fetchall()
        return columns
    except Exception as e:
        raise Exception(f"Ошибка получения колонок таблицы {table_name}: {e}")
    finally:
        cursor.close()


def get_table_data(connection, schema_name, table_name):
    try:
        cursor = connection.cursor()
        columns_info = get_table_columns(connection, schema_name, table_name)
        if not columns_info:
            raise Exception("Колонки таблицы не найдены.")

        column_definitions = ", ".join([f"{col[0]} {col[1]}" for col in columns_info])

        query = f"""
        SELECT * FROM get_table_data(%s, %s)
        AS t({column_definitions});
        """
        cursor.execute(query, (schema_name, table_name))
        data = cursor.fetchall()

        column_names = [col[0] for col in columns_info]

        result = {"columns": column_names, "data": data}
        return result
    except Exception as e:
        raise Exception(f"Ошибка получения данных из таблицы {table_name}: {e}")
    finally:
        cursor.close()


def insert_into_table(connection, table_name, schema_name, values):
    try:
        insert_functions = {
            "heroes": "insert_hero",
            "abilities": "insert_ability",
            "items": "insert_item",
            "builds": "insert_build",
            "build_items": "insert_build_item",
            "build_reviews": "insert_build_review"
        }

        function_name = insert_functions.get(table_name)
        if not function_name:
            raise ValueError(f"Не найдена функция для таблицы: {table_name}")

        values = [schema_name] + values
        placeholders = ", ".join(["%s"] * len(values))

        query = f"SELECT {function_name}({placeholders});"
        cursor = connection.cursor()
        cursor.execute(query, values)
        connection.commit()
        cursor.close()

    except Exception as e:
        raise Exception(f"Ошибка вставки данных в таблицу {table_name}: {e}")


def update_record(connection, schema_name, table_name, record_id, column_name, new_value):
    try:
        cursor = connection.cursor()
        query = """
            SELECT update_record_by_id(%s, %s, %s, %s, %s);
        """
        cursor.execute(query, (schema_name, table_name, record_id, column_name, new_value))
        connection.commit()
        cursor.close()
    except Exception as e:
        raise Exception(f"Ошибка обновления записи: {e}")


def get_top_heroes(connection, schema_name):
    try:
        cursor = connection.cursor()
        cursor.execute("SELECT * FROM get_top_heroes(%s);", (schema_name,))
        data = cursor.fetchall()
        return data
    except Exception as e:
        raise Exception(f"Ошибка получения топ героев: {e}")
    finally:
        cursor.close()


def get_top_builds(connection, schema_name):
    try:
        cursor = connection.cursor()
        cursor.execute("SELECT * FROM get_top_builds(%s);", (schema_name,))
        data = cursor.fetchall()
        return data
    except Exception as e:
        raise Exception(f"Ошибка получения топ сборок: {e}")
    finally:
        cursor.close()


def get_top_build_reviews(connection, schema_name):
    try:
        cursor = connection.cursor()
        cursor.execute("SELECT * FROM get_top_build_reviews(%s);", (schema_name,))
        data = cursor.fetchall()
        return data
    except Exception as e:
        raise Exception(f"Ошибка получения топ обзоров: {e}")
    finally:
        cursor.close()


def get_top_items_for_hero(connection, schema_name, hero_name):
    cursor = connection.cursor()
    cursor.execute("SELECT * FROM get_top_items_for_hero(%s, %s);", (schema_name, hero_name))
    return cursor.fetchall()


def get_abilities_by_hero_name(connection, schema_name, hero_name):
    cursor = connection.cursor()
    cursor.execute("SELECT * FROM get_abilities_by_hero_name(%s, %s);", (schema_name, hero_name))
    return cursor.fetchall()


def get_reviews_by_build(connection, schema_name, build_id):
    cursor = connection.cursor()
    cursor.execute("SELECT * FROM get_reviews_by_build(%s, %s);", (schema_name, build_id))
    return cursor.fetchall()


def get_items_by_build(connection, schema_name, build_id):
    cursor = connection.cursor()
    cursor.execute("SELECT * FROM get_items_by_build(%s, %s);", (schema_name, build_id))
    return cursor.fetchall()


def get_builds_by_hero(connection, schema_name, hero_name):
    cursor = connection.cursor()
    cursor.execute("SELECT * FROM get_builds_by_hero(%s, %s);", (schema_name, hero_name))
    return cursor.fetchall()
