from gui import *


class MainMenuFrame(tk.Frame):
    def __init__(self, master):
        super().__init__(master)
        self.master = master
        self.configure(bg="#ffffff")
        self._create_widgets()

    def _create_widgets(self):
        buttons_data = [
            ("Посмотреть таблицы", self._view_tables),
            ("Вставить в таблицу", self._insert_into_table),
            ("Обновить данные", self._update_table),
            ("Поиск", self._search_data),
            ("Топ герои", self._show_top_heroes),
            ("Топ предметы на героя", self._top_items_for_hero),
            ("Топ сборки", self._show_top_builds),
            ("Топ обзоры", self._show_top_reviews),
            ("Способности героя", self._abilities_by_hero),
            ("Отзывы о сборке", self._reviews_by_build),
            ("Предметы из сборки", self._items_by_build),
            ("Сборки героя", self._builds_by_hero),
        ]

        for idx, (text, command) in enumerate(buttons_data):
            row, col = divmod(idx, 4)
            tk.Button(
                self,
                text=text,
                command=command,
                width=25,
                height=2,
                bg="#dcdcdc",
                relief="groove"
            ).grid(row=row, column=col, padx=10, pady=10)

        lower_buttons_data = [
            ("Удалить из таблицы", self._delete_from_table),
            ("Удалить таблицу", self._delete_table),
            ("Удалить БД", self._delete_database)
        ]

        for idx, (text, command) in enumerate(lower_buttons_data):
            tk.Button(
                self,
                text=text,
                command=command,
                width=25,
                height=1,
                bg="#dcdcdc",
                relief="groove"
            ).grid(row=4, column=idx, padx=10, pady=10)

        tk.Button(
            self,
            text="Выйти",
            command=self.master.quit_application,
            width=10,
            height=1,
            bg="#ff4d4d",
            fg="white",
            relief="raised"
        ).grid(row=5, column=3, padx=10, pady=10, sticky="e")

    def _view_tables(self):
        self.master.show_table_selection(self._fetch_table_data)

    def _insert_into_table(self):
        self.master.show_table_selection(self._open_insert_window)

    def _fetch_table_data(self, schema_name, table_name):
        try:
            connection = self.master.connection
            data = get_table_data(connection, schema_name, table_name)
            TableViewWindow(self.master, table_name, data["columns"], data["data"])
        except Exception as e:
            messagebox.showerror("Ошибка", f"Не удалось загрузить данные таблицы: {e}")

    def _open_insert_window(self, schema_name, table_name):
        TableInsertWindow(self.master, table_name, schema_name, self.master.connection)

    def _update_table(self):
        self.master.show_table_selection(self._open_update_window)

    def _open_update_window(self, schema_name, table_name):
        TableUpdateWindow(self.master, table_name, schema_name, self.master.connection)

    def _search_data(self):
        SearchWindow(self.master, self.master.schema_name, self.master.connection)

    def _show_top_heroes(self):
        self._show_top_results("Топ герои", get_top_heroes, table_name="heroes")

    def _show_top_builds(self):
        self._show_top_results("Топ сборки", get_top_builds, table_name="builds")

    def _show_top_reviews(self):
        self._show_top_results("Топ обзоры", get_top_build_reviews, table_name=None)

    def _show_top_results(self, title, query_function, table_name):
        try:
            connection = self.master.connection
            schema_name = self.master.schema_name

            if title == "Топ обзоры":
                columns = ["ID сборки", "Средний рейтинг"]
            else:
                columns_info = get_table_columns(connection, schema_name, table_name)
                if not columns_info:
                    raise Exception("Колонки таблицы не найдены.")
                columns = [col[0] for col in columns_info]

            data = query_function(connection, schema_name)

            if data:
                TableViewWindow(self.master, title, columns, data)
            else:
                messagebox.showinfo("Результат", "Данные отсутствуют.")
        except Exception as e:
            messagebox.showerror("Ошибка", f"Не удалось загрузить данные: {e}")

    def _show_results_with_input(self, title, query_function, input_label, table_name):
        input_window = tk.Toplevel(self)
        input_window.title(title)
        input_window.geometry("400x200")

        tk.Label(input_window, text=input_label, font=("Arial", 14)).pack(pady=10)
        input_entry = tk.Entry(input_window, font=("Arial", 12))
        input_entry.pack(pady=5)

        def execute_query():
            user_input = input_entry.get()
            if not user_input:
                messagebox.showwarning("Ошибка", "Поле ввода не может быть пустым.")
                return
            if not user_input.isdigit():
                messagebox.showwarning("Ошибка ввода", "ID должен быть числом. Пожалуйста, введите корректный ID.")
                return

            try:
                schema_name = self.master.schema_name
                connection = self.master.connection
                user_input = int(user_input)
                data = query_function(connection, schema_name, user_input)

                if data:
                    columns_info = get_table_columns(connection, schema_name, table_name)
                    columns = [col[0] for col in columns_info]
                    TableViewWindow(self.master, title, columns, data)
                else:
                    messagebox.showinfo("Результат", "Данные отсутствуют.")
                input_window.destroy()
            except Exception as e:
                messagebox.showerror("Ошибка", f"Не удалось загрузить данные: {e}")

        tk.Button(input_window, text="Показать результаты", command=execute_query).pack(pady=10)

    def _top_items_for_hero(self):
        self._show_results_with_input(
            "Топ предметы на героя",
            get_top_items_for_hero,
            "Введите имя героя:",
            'items'
        )

    def _abilities_by_hero(self):
        self._show_results_with_input(
            "Способности героя",
            get_abilities_by_hero_name,
            "Введите имя героя:",
            'abilities'
        )

    def _reviews_by_build(self):
        self._show_results_with_input(
            "Отзывы о сборке",
            get_reviews_by_build,
            "Введите ID сборки:",
            'build_reviews'
        )

    def _items_by_build(self):
        self._show_results_with_input(
            "Предметы из сборки",
            get_items_by_build,
            "Введите ID сборки:",
            'items'
        )

    def _builds_by_hero(self):
        self._show_results_with_input(
            "Сборки героя",
            get_builds_by_hero,
            "Введите имя героя:",
            'builds'
        )

    def _delete_from_table(self):
        delete_window = tk.Toplevel(self.master)
        delete_window.title("Удаление из таблицы")
        delete_window.geometry("400x300")

        tk.Label(delete_window, text="Выберите действие:", font=("Arial", 14)).pack(pady=10)

        tk.Button(
            delete_window,
            text="Удалить отзыв по комментарию",
            command=lambda: self._delete_by_comment(delete_window),
            width=30
        ).pack(pady=5)

        tk.Button(
            delete_window,
            text="Удалить запись по ID",
            command=lambda: self.master.show_table_selection(self._delete_by_id),
            width=30
        ).pack(pady=5)

        tk.Button(
            delete_window,
            text="Очистить все таблицы",
            command=lambda: self._clear_all_tables(delete_window),
            width=30
        ).pack(pady=5)

        tk.Button(
            delete_window,
            text="Очистить одну таблицу",
            command=lambda: self.master.show_table_selection(self._clear_one_table),
            width=30
        ).pack(pady=5)

        tk.Button(delete_window, text="Закрыть", command=delete_window.destroy, width=30).pack(pady=5)

    def _clear_all_tables(self, parent_window):
        parent_window.destroy()
        try:
            connection = self.master.connection
            cursor = connection.cursor()
            cursor.execute("SELECT clear_all_tables(%s)", (self.master.schema_name,))
            connection.commit()
            cursor.close()
            messagebox.showinfo("Успех", "Все таблицы успешно очищены.")
        except Exception as e:
            messagebox.showerror("Ошибка", f"Ошибка при очистке всех таблиц: {e}")

    def _clear_one_table(self, schema_name, table_name):
        try:
            connection = self.master.connection
            cursor = connection.cursor()
            cursor.execute("SELECT clear_table(%s, %s)", (schema_name, table_name))
            connection.commit()
            cursor.close()
            messagebox.showinfo("Успех", f"Таблица '{table_name}' успешно очищена.")
        except Exception as e:
            messagebox.showerror("Ошибка", f"Ошибка при очистке таблицы '{table_name}': {e}")

    def _delete_by_comment(self, parent_window):
        parent_window.destroy()
        comment_window = tk.Toplevel(self.master)
        comment_window.title("Удалить отзыв по комментарию")
        comment_window.geometry("400x200")

        tk.Label(comment_window, text="Введите текст комментария:", font=("Arial", 12)).pack(pady=10)
        comment_entry = tk.Entry(comment_window, font=("Arial", 12))
        comment_entry.pack(pady=5)

        def execute_delete():
            comment_text = comment_entry.get()
            if not comment_text:
                messagebox.showerror("Ошибка", "Комментарий не может быть пустым.")
                return
            try:
                connection = self.master.connection
                cursor = connection.cursor()
                cursor.execute("SELECT delete_by_comment(%s, %s)", (self.master.schema_name, comment_text))
                connection.commit()
                cursor.close()
                messagebox.showinfo("Успех", "Удаление успешно выполнено.")
                comment_window.destroy()
            except Exception as e:
                messagebox.showerror("Ошибка", f"Ошибка при удалении: {e}")

        tk.Button(comment_window, text="Удалить", command=execute_delete, width=20).pack(pady=10)
        tk.Button(comment_window, text="Закрыть", command=comment_window.destroy, width=20).pack(pady=5)

    def _delete_by_id(self, schema_name, table_name):
        delete_id_window = tk.Toplevel(self.master)
        delete_id_window.title(f"Удалить запись по ID ({table_name})")
        delete_id_window.geometry("400x200")

        tk.Label(delete_id_window, text="Введите ID записи:", font=("Arial", 12)).pack(pady=10)
        id_entry = tk.Entry(delete_id_window, font=("Arial", 12))
        id_entry.pack(pady=5)

        def execute_delete():
            try:
                record_id = int(id_entry.get())
                connection = self.master.connection
                cursor = connection.cursor()
                cursor.execute("SELECT delete_by_first_column(%s, %s, %s)", (schema_name, table_name, record_id))
                connection.commit()
                cursor.close()
                messagebox.showinfo("Успех", "Удаление успешно выполнено.")
                delete_id_window.destroy()
            except ValueError:
                messagebox.showerror("Ошибка", "ID должен быть числом.")
            except Exception as e:
                messagebox.showerror("Ошибка", f"Ошибка при удалении: {e}")

        tk.Button(delete_id_window, text="Удалить", command=execute_delete, width=20).pack(pady=10)
        tk.Button(delete_id_window, text="Закрыть", command=delete_id_window.destroy, width=20).pack(pady=5)

    def _delete_table(self):
        delete_window = tk.Toplevel(self.master)
        delete_window.title("Удаление таблицы")
        delete_window.geometry("400x200")

        tk.Label(delete_window, text="Выберите действие:", font=("Arial", 14)).pack(pady=10)

        tk.Button(
            delete_window,
            text="Удалить все таблицы",
            command=lambda: self._delete_all_tables(delete_window),
            width=30
        ).pack(pady=5)

        tk.Button(
            delete_window,
            text="Удалить 1 таблицу",
            command=lambda: self.master.show_table_selection(self._delete_one_table),
            width=30
        ).pack(pady=5)

        tk.Button(delete_window, text="Закрыть", command=delete_window.destroy, width=30).pack(pady=5)

    def _delete_all_tables(self, parent_window):
        parent_window.destroy()
        try:
            connection = self.master.connection
            cursor = connection.cursor()
            cursor.execute("SELECT delete_all_tables_in_schema(%s)", (self.master.schema_name,))
            connection.commit()
            cursor.close()
            messagebox.showinfo("Успех", "Все таблицы успешно удалены.")
        except Exception as e:
            messagebox.showerror("Ошибка", f"Ошибка при удалении всех таблиц: {e}")

    def _delete_one_table(self, schema_name, table_name):
        try:
            connection = self.master.connection
            cursor = connection.cursor()
            cursor.execute("SELECT delete_table(%s, %s)", (schema_name, table_name))
            connection.commit()
            cursor.close()
            messagebox.showinfo("Успех", f"Таблица '{table_name}' успешно удалена.")
        except Exception as e:
            messagebox.showerror("Ошибка", f"Ошибка при удалении таблицы '{table_name}': {e}")

    def _delete_database(self):
        confirm_window = tk.Toplevel(self.master)
        confirm_window.title("Удаление базы данных")
        confirm_window.geometry("400x150")

        tk.Label(confirm_window, text="Вы уверены, что хотите удалить вашу БД?", font=("Arial", 14)).pack(pady=10)

        button_frame = tk.Frame(confirm_window)
        button_frame.pack(pady=10)

        tk.Button(
            button_frame,
            text="Да",
            command=lambda: self._execute_delete_schema(confirm_window),
            width=10,
            bg="#ff4d4d",
            fg="white"
        ).grid(row=0, column=0, padx=10)

        tk.Button(
            button_frame,
            text="Нет",
            command=confirm_window.destroy,
            width=10,
            bg="#dcdcdc"
        ).grid(row=0, column=1, padx=10)

    def _execute_delete_schema(self, window):
        try:
            connection = self.master.connection
            cursor = connection.cursor()

            cursor.execute("SELECT delete_schema(%s)", (self.master.schema_name,))
            connection.commit()
            cursor.close()

            messagebox.showinfo("Успех", f"База данных '{self.master.schema_name}' успешно удалена.")
            self.master.disconnect_from_db()
            window.destroy()
            self.master.switch_to_registration()
        except Exception as e:
            messagebox.showerror("Ошибка", f"Ошибка при удалении базы данных: {e}")
            window.destroy()
