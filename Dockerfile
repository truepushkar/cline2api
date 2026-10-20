# cline2api — Python Flask server
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY server.py cline_oauth.py ./

ENV PORT=8080 HOST=0.0.0.0
EXPOSE 8080

# Required runtime env:
#   docker run -p 8080:8080 \
#     -e CLINE_REFRESH_TOKEN='<refreshToken>' \
#     -e API_KEY='<client key>' \
#     cline2api
CMD ["sh", "-c", "exec python server.py"]
