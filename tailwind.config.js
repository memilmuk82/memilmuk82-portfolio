/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./app/templates/**/*.html", "./app/static/js/**/*.js"],
  theme: {
    extend: {
      colors: {
        paper: "#F7F7F3",
        ink: "#07162F",
        cobalt: "#0B43F4",
        citron: "#D9FF00"
      }
    }
  },
  plugins: []
};
