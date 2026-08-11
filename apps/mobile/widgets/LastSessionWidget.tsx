export type LastSessionProps = {
  location: string;
  costLabel: string;
  energyLabel: string;
  dateLabel: string;
};

/** Web/Android stub — widgets are iOS-only via expo-widgets. */
const LastSessionWidget = {
  updateSnapshot(_props: LastSessionProps) {},
  reload() {},
  updateTimeline(_entries: { date: Date; props: LastSessionProps }[]) {},
};

export default LastSessionWidget;
