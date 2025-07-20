# syntax = docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=3.4.2
FROM ruby:$RUBY_VERSION-alpine AS base

# Rails app lives here
WORKDIR /rails

# Set production environment
#ENV RAILS_ENV="production" \
#    BUNDLE_DEPLOYMENT="1" \
#    BUNDLE_PATH="/usr/local/bundle" \
#    BUNDLE_WITHOUT="development"


# Install packages needed to build gems
RUN apk update \
&& apk upgrade \
&& apk add --update --no-cache \
    build-base git libpq-dev tzdata libffi-dev \
    pkgconf python3 py3-pip yaml-dev\
    curl vips-dev


COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Install packages needed for deployment
RUN apk update \
&& apk upgrade \
&& apk add --update --no-cache postgresql-client bash

RUN chmod +x bin/dev

CMD ["./bin/dev"]
#CMD ["tail", "-f", "/dev/null"]
