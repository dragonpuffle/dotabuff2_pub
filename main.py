from application import Application

if __name__ == "__main__":
    try:
        app = Application()
        app.mainloop()
    except Exception as e:
        print(f"Ошибка при запуске приложения: {e}")
#