FROM alpine
MAINTAINER Andrew Rothstein andrew.rothstein@gmail.com

ENV IB_PATH /idempotent-bash
RUN mkdir -p $IB_PATH
ADD setup.sh $IB_PATH/setup.sh
ENV PATH ${PATH}:$IB_PATH

CMD $IB_PATH/setup.sh
