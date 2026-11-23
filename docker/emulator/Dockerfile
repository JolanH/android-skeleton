# Skeleton emulator image: Pixel 8 / API 34 emulator viewable in the browser (noVNC). Needs /dev/kvm.
# Built on top of skeleton-dev so the Android SDK is shared. Build via ./dev.sh emulator.
ARG BASE_IMAGE=skeleton-dev:latest
FROM ${BASE_IMAGE}

ARG SYSTEM_IMAGE="system-images;android-34;google_apis;x86_64"

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends xvfb x11-utils x11vnc novnc websockify procps \
       libpulse0 libnss3 libgl1 libxcomposite1 libxcursor1 libxdamage1 libxi6 libxtst6 libasound2 \
    && rm -rf /var/lib/apt/lists/*

RUN sdkmanager "emulator" "${SYSTEM_IMAGE}" \
    && chmod -R a+rwX ${ANDROID_HOME}

COPY entrypoint.sh /usr/local/bin/emulator-entrypoint.sh
RUN chmod +x /usr/local/bin/emulator-entrypoint.sh

ENV HOME=/home/emu \
    DISPLAY=:0 \
    AVD_NAME=pixel8 \
    SYSTEM_IMAGE=${SYSTEM_IMAGE}
EXPOSE 6080
ENTRYPOINT ["/usr/local/bin/emulator-entrypoint.sh"]
