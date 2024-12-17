import tkinter as tk
from tkinter import messagebox, ttk
from db import *


class TableViewWindow(tk.Toplevel):
    def __init__(self, parent, table_name, columns, data):
        super().__init__(parent)
        self.title(f"Таблица: {table_name}")
        self.geometry("800x400")

        frame = tk.Frame(self)
        frame.pack(expand=True, fill="both")

        scrollbar_y = ttk.Scrollbar(frame, orient="vertical")
        scrollbar_x = ttk.Scrollbar(frame, orient="horizontal")

        tree = ttk.Treeview(
            frame,
            columns=columns,
            show="headings",
            yscrollcommand=scrollbar_y.set,
            xscrollcommand=scrollbar_x.set
        )

        scrollbar_y.config(command=tree.yview)
        scrollbar_x.config(command=tree.xview)

        scrollbar_y.pack(side="right", fill="y")
        scrollbar_x.pack(side="bottom", fill="x")
        tree.pack(expand=True, fill="both")

        for col in columns:
            tree.heading(col, text=col)
            tree.column(col, anchor="center", width=100)

        for row in data:
            tree.insert("", "end", values=row)

        self._adjust_column_width(tree, columns, data)

        tk.Button(self, text="Вернуться на главное меню", command=self.destroy, bg="#dcdcdc").pack(pady=5)

    def _adjust_column_width(self, tree, columns, data):
        for col_idx, col in enumerate(columns):
            max_length = max(len(str(row[col_idx])) for row in data) if data else 10
            col_width = max(min(max_length * 10, 200), 50)
            tree.column(col, width=col_width, stretch=True)


class TableInsertWindow(tk.Toplevel):
    def __init__(self, parent, table_name, schema_name, connection):
        super().__init__(parent)
        self.title(f"Вставка в таблицу: {table_name}")
        self.geometry("600x400")
        self.schema_name = schema_name
        self.table_name = table_name
        self.connection = connection
        self.entries = {}
        self._create_insert_fields()

    def _create_insert_fields(self):
        fields = self._get_fields_by_table()
        tk.Label(self, text="Заполните данные:", font=("Arial", 14)).pack(pady=10)
        form_frame = tk.Frame(self)
        form_frame.pack(pady=10)

        for idx, (field_name, _) in enumerate(fields):
            tk.Label(form_frame, text=field_name, font=("Arial", 12)).grid(row=idx, column=0, padx=10, pady=5)
            entry = tk.Entry(form_frame, font=("Arial", 12))
            entry.grid(row=idx, column=1, padx=10, pady=5)
            self.entries[field_name] = entry

        tk.Button(self, text="Вставить", command=lambda: self._insert_data(fields), bg="#dcdcdc").pack(pady=5)
        tk.Button(self, text="Вернуться на главное меню", command=self.destroy, bg="#dcdcdc").pack(pady=5)

    def _get_fields_by_table(self):
        table_fields = {
            "heroes": [("name", "str"), ("tier", "str"), ("win_rate", "float"), ("pick_rate", "float"),
                       ("ban_rate", "float")],
            "abilities": [("hero_id", "int"), ("name", "str"), ("description", "str"), ("type", "str")],
            "items": [("name", "str"), ("cost", "int"), ("type", "str")],
            "builds": [("name", "str"), ("hero_id", "int"), ("build_owner", "str"), ("win_rate", "float"),
                       ("games_played", "int")],
            "build_items": [("build_id", "int"), ("item_id", "int")],
            "build_reviews": [("build_id", "int"), ("user_id", "int"), ("rating", "int"), ("comment", "str")]
        }
        return table_fields.get(self.table_name, [])

    def _insert_data(self, fields):
        try:
            values = []
            for field, field_type in fields:
                raw_value = self.entries[field].get()
                if not raw_value:
                    raise ValueError(f"Поле '{field}' не может быть пустым.")

                if field_type == "int":
                    values.append(int(raw_value))
                elif field_type == "float":
                    values.append(float(raw_value))
                elif field_type == "str":
                    values.append(str(raw_value))
                else:
                    raise ValueError(f"Неподдерживаемый тип данных для поля '{field}'.")

            insert_into_table(self.connection, self.table_name, self.schema_name, values)
            messagebox.showinfo("Успех", "Данные успешно вставлены!")
            self.destroy()
        except ValueError as ve:
            messagebox.showerror("Ошибка валидации", f"Некорректное значение: {ve}")
        except Exception as e:
            messagebox.showerror("Ошибка", f"Не удалось вставить данные: {e}")


class TableSelectionFrame(tk.Frame):
    def __init__(self, master, callback):
        super().__init__(master)
        self.master = master
        self.callback = callback
        self.configure(bg="#ffffff")
        self._create_widgets()

    def _create_widgets(self):
        tables = ["heroes", "abilities", "items", "builds", "build_items", "build_reviews"]
        tk.Label(self, text="Выберите таблицу:", font=("Arial", 16), bg="#ffffff").pack(pady=10)
        for table in tables:
            tk.Button(self, text=table, command=lambda t=table: self._handle_selection(t), width=20, height=2).pack(
                pady=5)
        tk.Button(self, text="Вернуться на главное меню", command=self.master.switch_to_main_menu, bg="#dcdcdc").pack(
            pady=10)

    def _handle_selection(self, table_name):
        if self.callback:
            self.callback(self.master.schema_name, table_name)


class TableUpdateWindow(tk.Toplevel):
    def __init__(self, parent, table_name, schema_name, connection):
        super().__init__(parent)
        self.title(f"Обновление записи в таблице: {table_name}")
        self.geometry("500x300")
        self.schema_name = schema_name
        self.table_name = table_name
        self.connection = connection
        self.entries = {}
        self.columns = self._get_table_columns()
        self._create_widgets()

    def _get_table_columns(self):
        try:
            columns_info = get_table_columns(self.connection, self.schema_name, self.table_name)
            columns = [col[0] for col in columns_info]
            return columns
        except Exception as e:
            messagebox.showerror("Ошибка", f"Не удалось получить столбцы таблицы: {e}")
            return []

    def _create_widgets(self):
        tk.Label(self, text="Введите ID записи:", font=("Arial", 12)).pack(pady=5)
        self.id_entry = tk.Entry(self, font=("Arial", 12))
        self.id_entry.pack(pady=5)

        tk.Label(self, text="Выберите столбец:", font=("Arial", 12)).pack(pady=5)
        self.column_combobox = ttk.Combobox(self, values=self.columns, state="readonly")
        self.column_combobox.pack(pady=5)

        tk.Label(self, text="Введите новое значение:", font=("Arial", 12)).pack(pady=5)
        self.new_value_entry = tk.Entry(self, font=("Arial", 12))
        self.new_value_entry.pack(pady=5)

        tk.Button(self, text="Обновить запись", command=self._update_record, bg="#dcdcdc").pack(pady=10)
        tk.Button(self, text="Закрыть", command=self.destroy, bg="#dcdcdc").pack(pady=5)

    def _update_record(self):
        try:
            record_id = int(self.id_entry.get())
            column_name = self.column_combobox.get()
            new_value = self.new_value_entry.get()

            if not column_name:
                messagebox.showerror("Ошибка", "Выберите столбец для обновления!")
                return

            columns_info = get_table_columns(self.connection, self.schema_name, self.table_name)
            column_types = {col[0]: col[1] for col in columns_info}
            column_type = column_types.get(column_name)

            if column_type in ("integer", "int"):
                new_value = int(new_value)
            elif column_type in ("numeric", "float", "double precision"):
                new_value = float(new_value)
                if abs(new_value) > 999.99:
                    raise ValueError("Значение для numeric(5,2) не может превышать диапазон от -999.99 до 999.99")
                new_value = f"{new_value:.2f}"
            elif column_type in ("character varying", "text"):
                new_value = str(new_value)
            else:
                raise ValueError("Неподдерживаемый тип данных!")

            new_value = str(new_value)

            update_record(self.connection, self.schema_name, self.table_name, record_id, column_name, new_value)
            messagebox.showinfo("Успех", "Запись успешно обновлена!")
            self.destroy()
        except ValueError:
            messagebox.showerror("Ошибка", "ID должен быть числом и значение должно соответствовать типу столбца!")
        except Exception as e:
            messagebox.showerror("Ошибка", f"Не удалось обновить запись: {e}")


class SearchWindow(tk.Toplevel):
    def __init__(self, parent, schema_name, connection):
        super().__init__(parent)
        self.title("Поиск данных")
        self.geometry("400x300")
        self.schema_name = schema_name
        self.connection = connection
        self._create_widgets()

    def _create_widgets(self):
        tk.Label(self, text="Выберите тип поиска:", font=("Arial", 14)).pack(pady=10)

        search_buttons = [
            ("Поиск записи по ID", self._search_by_id),
            ("Поиск способности по описанию", lambda: self._search_by_text("description")),
            ("Поиск героя по имени", lambda: self._search_by_text("name")),
            ("Поиск предмета по имени", lambda: self._search_by_text("item_name")),
            ("Поиск отзыва по комментарию", lambda: self._search_by_text("comment"))
        ]

        for text, command in search_buttons:
            tk.Button(self, text=text, command=command, width=30, bg="#dcdcdc").pack(pady=5)

        tk.Button(self, text="Закрыть", command=self.destroy, bg="#dcdcdc").pack(pady=10)

    def _search_by_id(self):
        self.destroy()
        self.master.show_table_selection(self._open_search_by_id_window)

    def _open_search_by_id_window(self, schema_name, table_name):
        SearchByIDWindow(self, schema_name, table_name, self.connection)

    def _search_by_text(self, search_type):
        SearchByTextWindow(self, self.schema_name, self.connection, search_type)


class SearchByIDWindow(tk.Toplevel):
    def __init__(self, parent, schema_name, table_name, connection):
        super().__init__()
        self.title(f"Поиск записи по ID в таблице: {table_name}")
        self.geometry("400x300")
        self.schema_name = schema_name
        self.table_name = table_name
        self.connection = connection

        self._create_widgets()

    def _create_widgets(self):
        tk.Label(self, text="Введите ID записи:", font=("Arial", 12)).pack(pady=10)
        self.id_entry = tk.Entry(self, font=("Arial", 12))
        self.id_entry.pack(pady=5)

        tk.Button(self, text="Найти", command=self._execute_search, bg="#dcdcdc").pack(pady=10)
        tk.Button(self, text="Закрыть", command=self.destroy, bg="#dcdcdc").pack(pady=5)

    def _execute_search(self):
        try:
            record_id = int(self.id_entry.get())
            cursor = self.connection.cursor()

            columns_info = get_table_columns(self.connection, self.schema_name, self.table_name)
            if not columns_info:
                raise Exception("Колонки таблицы не найдены.")

            column_definitions = ", ".join([f"{col[0]} {col[1]}" for col in columns_info])

            query = f"""
            SELECT * FROM search_by_first_column(%s, %s, %s)
            AS t({column_definitions});
            """
            cursor.execute(query, (self.schema_name, self.table_name, record_id))
            data = cursor.fetchall()
            columns = [col[0] for col in columns_info]

            cursor.close()

            if data:
                TableViewWindow(self, self.table_name, columns, data)
            else:
                messagebox.showinfo("Результат", "Запись не найдена!")
        except ValueError:
            messagebox.showerror("Ошибка", "ID должен быть числом!")
        except Exception as e:
            messagebox.showerror("Ошибка", f"Ошибка поиска: {e}")


class SearchByTextWindow(tk.Toplevel):
    def __init__(self, parent, schema_name, connection, search_type):
        super().__init__(parent)
        self.title("Поиск по тексту")
        self.geometry("400x200")
        self.schema_name = schema_name
        self.connection = connection
        self.search_type = search_type
        self._create_widgets()

    def _create_widgets(self):
        label_text = {
            "description": "Введите описание способности:",
            "name": "Введите имя героя:",
            "item_name": "Введите имя предмета:",
            "comment": "Введите текст комментария:"
        }
        tk.Label(self, text=label_text[self.search_type], font=("Arial", 12)).pack(pady=10)
        self.search_entry = tk.Entry(self, font=("Arial", 12))
        self.search_entry.pack(pady=5)

        tk.Button(self, text="Найти", command=self._execute_search, bg="#dcdcdc").pack(pady=10)
        tk.Button(self, text="Закрыть", command=self.destroy, bg="#dcdcdc").pack(pady=5)

    def _execute_search(self):
        try:
            search_text = self.search_entry.get()
            cursor = self.connection.cursor()

            if self.search_type == "description":
                cursor.execute("SELECT * FROM search_by_description(%s, %s)", (self.schema_name, search_text))
            elif self.search_type == "name":
                cursor.execute("SELECT * FROM search_by_name(%s, %s)", (self.schema_name, search_text))
            elif self.search_type == "item_name":
                cursor.execute("SELECT * FROM search_item_by_name(%s, %s)", (self.schema_name, search_text))
            elif self.search_type == "comment":
                cursor.execute("SELECT * FROM search_by_comment(%s, %s)", (self.schema_name, search_text))

            data = cursor.fetchall()
            columns = [desc[0] for desc in cursor.description]
            cursor.close()

            if data:
                TableViewWindow(self, "Результат поиска", columns, data)
            else:
                messagebox.showinfo("Результат", "Ничего не найдено!")
        except Exception as e:
            messagebox.showerror("Ошибка", f"Ошибка поиска: {e}")
