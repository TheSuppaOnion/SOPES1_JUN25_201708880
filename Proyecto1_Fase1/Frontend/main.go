package main

import (
    "log"
	"os"

    "github.com/gofiber/fiber/v2"
    "github.com/gofiber/template/html/v2"
)

func main() {
    // Inicializar motor de plantillas HTML
    engine := html.New("./views", ".html")

    // Crear aplicación Fiber con el motor de plantillas
    app := fiber.New(fiber.Config{
        Views: engine,
    })

    // Servir archivos estáticos
    //app.Static("/static", "./static")

    // Ruta principal que renderiza la vista index.html
    app.Get("/", func(c *fiber.Ctx) error {
        // Puedes pasar variables al template si es necesario
        return c.Render("index", fiber.Map{
            "Title": "Monitor de Sistema en Tiempo Real",
            "ApiUrl": getEnvOrDefault("API_URL", "http://localhost:3000"),
        })
    })

    // Iniciar el servidor
    log.Fatal(app.Listen(":8080"))
}

// getEnvOrDefault obtiene una variable de entorno o devuelve un valor predeterminado
func getEnvOrDefault(key, defaultValue string) string {
    value := os.Getenv(key)
    if value == "" {
        return defaultValue
    }
    return value
}