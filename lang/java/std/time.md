`java.time`用于表示时间对象的接口为`Temporal`（例如日期，时间，时区偏移等），并且由下面几个核心接口围绕构建而成：

- TemporalAccessor: 定义对`Temporal`对象的访问方法
- Temporal: 定义对时间对象的读写访问，例如日期，时间以及它们的结合等
- TemporalAdjuster: 调整时间对象的策略接口
- TemporalField: 将时间线划分为对人类有意义的字段，例如`SECOND_OF_MINUTE`， `SECOND_OF_DAY`
- TemporalUnit: 时间单位，例如纳秒，秒，分钟等
- TemporalAmount: 定义时间的大小，例如`六小时`，`两年三个月`
- TemporalQuery: 查询时间对象的策略接口，例如查询某个日期对象的年份

