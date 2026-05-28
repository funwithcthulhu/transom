export type PingReq = {
  message: string;
};

export type PingRes = {
  message: string;
};

export type CountReq = {
  upto: number;
};

export type CountRes = {
  total: number;
};

export type CountEvent = {
  value: number;
};
