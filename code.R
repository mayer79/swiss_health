library(tidyverse)
library(readxl)
library(plotly)

# This script shows by how much the lowest possible health insurance premiums in Swiss
# jump from 2023 to 2024, given the maximal possible Franchise of 2500, being adult,
# and not requiring an accident insurance. You will get a result for each premium region,
# which is a combination of canton and up to three sub-regions in some cantons.

# Data sources: Federal Office of Public Health (BAG), see README for details

p0 <- read_delim("premiums_2023.csv", delim = ";", locale = locale(encoding = "latin1"))
p1 <- read_delim("premiums_2024.csv", delim = ";", locale = locale(encoding = "latin1"))
kk <- read_excel(
  "insurers_2023.xlsx", 
  sheet = 2, 
  skip = 5, 
  col_names = c("Versicherer", "Insurer"),
  col_types = c("numeric", "skip", "text", "skip")
)

# Prepare data
both <- p0 |> 
  bind_rows(p1) |>
  filter(!(Kanton %in% c("ZE", "ZR"))) |>
  mutate(Versicherer = parse_number(Versicherer)) |> # Strange format otherwise
  left_join(kk, by = "Versicherer") |> 
  rename(Premium = Prämie, Year = Geschäftsjahr) |> 
  mutate(
    Year = factor(Year),
    Name = paste0(Insurer, " (", Tarifbezeichnung, ")"),
    Where = ifelse(Region == "PR-REG CH0", Kanton, paste(Kanton, str_sub(Region, -1))),
    Where = factor(Where, levels = rev(sort(unique(Where))))
  )

# Pick the smallest premium per year and region, and per other premium-relevant factors
both_min <- both |> 
  slice_min(Premium, by = c(Year, Where, Altersklasse, Unfalleinschluss, Franchise))
  
## Pick any combination of Altersklasse, Unfalleinschluss, Franchise
to_plot <- both_min |>
  filter(
    Altersklasse == "AKL-ERW", 
    Unfalleinschluss == "OHN-UNF", 
    Franchise == "FRA-2500"
  )

# Not considered: Fixed reduction ("Vergütung"): 5.34 CHF (2024), 5.10 CHF (2023)

# In what region is my municipality? Check
# https://www.bag.admin.ch/bag/de/home/versicherungen/krankenversicherung/krankenversicherung-versicherer-aufsicht/praemienregionen.html

p <- ggplot(to_plot, aes(x = Premium, y = Where, kk = Name)) + 
  geom_point(aes(shape = Year), color = "darkorange") +
  geom_line(aes(group = Where), color = "darkorange", linewidth = 0.3) +
  labs(x = "Premium (CHF)", y = "Canton/Region (1 = town)") +
  ggtitle("Lowest tariff 23/24", subtitle = "(no accident, 2500 Franchise)") + 
  theme_bw()
p
# ggsave("f2500_noaccident.png", plot = p, width = 5, height = 6)
# ggsave("f2500_noaccident.svg", plot = p, width = 5, height = 6)

# Interactive (ignore the warnings)
p_inter <- ggplotly(p, width = 500, height = 600) |> 
  add_trace(mode = "markers", text = ~kk)
p_inter
# htmlwidgets::saveWidget(p_inter, "docs/f2500_noaccident.html")
