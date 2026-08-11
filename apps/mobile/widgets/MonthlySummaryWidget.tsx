export type MonthlySummaryProps = {
  monthLabel: string;
  costLabel: string;
  energyLabel: string;
};

/** Web/Android stub — widgets are iOS-only via expo-widgets. */
const MonthlySummaryWidget = {
  updateSnapshot(_props: MonthlySummaryProps) {},
  reload() {},
  updateTimeline(_entries: { date: Date; props: MonthlySummaryProps }[]) {},
};

export default MonthlySummaryWidget;
