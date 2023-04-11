FROM ruby:2.7.4

RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

RUN apt-get update && \
    apt-get install -y ffmpeg

WORKDIR /app

# スクリプトに変更があっても、bundle installをキャッシュさせる
COPY Gemfile /app/
COPY Gemfile.lock /app/
RUN bundle install --deployment --without=test --jobs 4

COPY . /app/
