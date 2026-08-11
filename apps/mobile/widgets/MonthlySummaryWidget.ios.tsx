import { HStack, Text, VStack } from '@expo/ui/swift-ui';
import {
  font,
  foregroundStyle,
  padding,
} from '@expo/ui/swift-ui/modifiers';
import { createWidget, type WidgetEnvironment } from 'expo-widgets';

export type MonthlySummaryProps = {
  monthLabel: string;
  costLabel: string;
  energyLabel: string;
};

const MonthlySummaryLayout = (
  props: MonthlySummaryProps,
  environment: WidgetEnvironment,
) => {
  'widget';

  const accent = environment.colorScheme === 'dark' ? '#00A3FF' : '#0077B8';
  const primary = environment.colorScheme === 'dark' ? '#F4F7FA' : '#0B1C2C';
  const secondary = environment.colorScheme === 'dark' ? '#9BB0C3' : '#5A7188';

  if (environment.widgetFamily === 'systemSmall') {
    return (
      <VStack
        alignment="leading"
        modifiers={[padding({ all: 12 })]}
      >
        <Text modifiers={[font({ size: 12, weight: 'semibold' }), foregroundStyle(accent)]}>
          EVAi
        </Text>
        <Text modifiers={[font({ size: 11 }), foregroundStyle(secondary)]}>
          {props.monthLabel}
        </Text>
        <Text modifiers={[font({ size: 22, weight: 'bold' }), foregroundStyle(primary)]}>
          {props.costLabel}
        </Text>
        <Text modifiers={[font({ size: 11 }), foregroundStyle(secondary)]}>
          {props.energyLabel}
        </Text>
      </VStack>
    );
  }

  return (
    <VStack alignment="leading" modifiers={[padding({ all: 14 })]}>
      <HStack>
        <Text modifiers={[font({ size: 14, weight: 'bold' }), foregroundStyle(accent)]}>
          EVAi
        </Text>
        <Text modifiers={[font({ size: 12 }), foregroundStyle(secondary)]}>
          {props.monthLabel}
        </Text>
      </HStack>
      <Text modifiers={[font({ size: 12 }), foregroundStyle(secondary)]}>
        Monthly cost
      </Text>
      <Text modifiers={[font({ size: 28, weight: 'bold' }), foregroundStyle(primary)]}>
        {props.costLabel}
      </Text>
      <Text modifiers={[font({ size: 13 }), foregroundStyle(secondary)]}>
        Energy · {props.energyLabel}
      </Text>
    </VStack>
  );
};

const MonthlySummaryWidget = createWidget(
  'MonthlySummaryWidget',
  MonthlySummaryLayout,
);

export default MonthlySummaryWidget;
