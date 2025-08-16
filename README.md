# Saumon Net

Saumon-Net is a Rails 8 application designed to scrape, process, and store data produced by French Institutions. 

The application fetches datasets from official websites, processes them, and stores them in a structured format for further analysis.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)

## Prerequisites

Before you begin, ensure you have the following installed:

- **Ruby**: 3.4.2 (see [.ruby-version](.ruby-version))
- **Rails**: 8.0
- **PostgreSQL**: 17

## Installation

### Docker Development

1. **Build and start services**
   ```bash
   docker compose up --build
   ```

2. **Setup the database**
   ```bash
   docker compose exec web bin/rails db:prepare
   ```

The application will be available at `http://localhost:3004`
