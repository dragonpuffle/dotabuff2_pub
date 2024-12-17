import tkinter as tk
from tkinter import messagebox, ttk
from utils import validate_credentials
from main_menu_frame import *


class Application(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Главное меню")
        self.geometry("850x620")
        self.configure(bg="#f0f0f0")
        self.current_frame = None
        self.connection = None
        self.schema_name = None
        self.switch_to_registration()

    def connect_to_db(self, username, password):
        self.connection = login_user(username, password)
        self.schema_name = f"schema_{username}"

    def disconnect_from_db(self):
        if self.connection:
            self.connection.close()
            self.connection = None

    def switch_to_login(self):
        self._clear_frame()
        self.current_frame = LoginFrame(self)
        self.current_frame.pack(expand=True, fill="both")

    def switch_to_registration(self):
        self._clear_frame()
        self.current_frame = RegistrationFrame(self)
        self.current_frame.pack(expand=True, fill="both")

    def switch_to_main_menu(self):
        self._clear_frame()
        self.current_frame = MainMenuFrame(self)
        self.current_frame.pack(expand=True, fill="both")

    def show_table_selection(self, callback):
        self._clear_frame()
        self.current_frame = TableSelectionFrame(self, callback)
        self.current_frame.pack(expand=True, fill="both")

    def _clear_frame(self):
        if self.current_frame:
            self.current_frame.pack_forget()

    def quit_application(self):
        self.disconnect_from_db()
        self.destroy()


class LoginFrame(tk.Frame):
    def __init__(self, master):
        super().__init__(master)
        self.master = master
        self.configure(bg="#ffffff")
        self._create_widgets()

    def _create_widgets(self):
        tk.Label(self, text="Имя пользователя:", font=("Arial", 14)).grid(row=0, column=0, padx=10, pady=10)
        self.username_entry = tk.Entry(self, font=("Arial", 12))
        self.username_entry.grid(row=0, column=1, padx=10, pady=10)

        tk.Label(self, text="Пароль:", font=("Arial", 14)).grid(row=1, column=0, padx=10, pady=10)
        self.password_entry = tk.Entry(self, show="*", font=("Arial", 12))
        self.password_entry.grid(row=1, column=1, padx=10, pady=10)

        tk.Button(self, text="Войти", command=self._handle_login, font=("Arial", 12), width=20).grid(row=2, column=0,
                                                                                                     columnspan=2,
                                                                                                     pady=15)
        tk.Button(
            self,
            text="Нет аккаунта?\nЗарегистрироваться",
            command=self.master.switch_to_registration,
            font=("Arial", 12),
            width=25,
            justify="center"
        ).grid(row=3, column=0, columnspan=2, pady=10)

    def _handle_login(self):
        username = self.username_entry.get()
        password = self.password_entry.get()
        valid, message = validate_credentials(username, password)

        if valid:
            try:
                if login_user(username, password):
                    self.master.connect_to_db(username, password)
                    messagebox.showinfo("Успех", "Успешный вход!")
                    self.master.switch_to_main_menu()
                else:
                    messagebox.showerror("Ошибка", "Неверное имя пользователя или пароль.")
            except Exception as e:
                messagebox.showerror("Ошибка", f"Ошибка входа: {e}")
        else:
            messagebox.showerror("Ошибка", message)


class RegistrationFrame(tk.Frame):
    def __init__(self, master):
        super().__init__(master)
        self.master = master
        self.configure(bg="#ffffff")
        self._create_widgets()

    def _create_widgets(self):
        tk.Label(self, text="Имя пользователя:", font=("Arial", 14)).grid(row=0, column=0, padx=10, pady=10)
        self.username_entry = tk.Entry(self, font=("Arial", 12))
        self.username_entry.grid(row=0, column=1, padx=10, pady=10)

        tk.Label(self, text="Пароль:", font=("Arial", 14)).grid(row=1, column=0, padx=10, pady=10)
        self.password_entry = tk.Entry(self, show="*", font=("Arial", 12))
        self.password_entry.grid(row=1, column=1, padx=10, pady=10)

        tk.Button(self, text="Регистрация", command=self._handle_registration, font=("Arial", 12), width=20).grid(row=2,
                                                                                                                  column=0,
                                                                                                                  columnspan=2,
                                                                                                                  pady=15)
        tk.Button(self, text="Уже есть аккаунт? Войти", command=self.master.switch_to_login, font=("Arial", 12),
                  width=20).grid(row=3, column=0, columnspan=2, pady=10)

    def _handle_registration(self):
        username = self.username_entry.get()
        password = self.password_entry.get()
        valid, message = validate_credentials(username, password)

        if valid:
            try:
                register_user(username, password)
                self.master.connect_to_db(username, password)
                messagebox.showinfo("Успех", "Регистрация прошла успешно!")
                self.master.switch_to_login()
            except Exception as e:
                messagebox.showerror("Ошибка", f"Ошибка регистрации: {e}")
        else:
            messagebox.showerror("Ошибка", message)
