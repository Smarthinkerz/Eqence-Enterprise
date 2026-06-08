import React, { useState } from 'react';
import { ChevronDown, Plus, MapPin } from 'lucide-react';
import { useOrganization } from '../contexts/OrganizationContext';
import { useI18n } from '../contexts/I18nContext';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from './ui/select';
import { Button } from './ui/button';

export function LocationSwitcher() {
  const { currentLocation, locations, setCurrentLocation, can } = useOrganization();
  const { t } = useI18n();

  const handleLocationChange = (locationId: string) => {
    const location = locations.find(l => l.id === locationId);
    if (location) {
      setCurrentLocation(location);
    }
  };

  return (
    <div className="flex items-center gap-2">
      <Select value={currentLocation?.id || ''} onValueChange={handleLocationChange}>
        <SelectTrigger className="w-[200px]">
          <div className="flex items-center gap-2">
            <MapPin className="w-4 h-4" />
            <SelectValue placeholder="Select location" />
          </div>
        </SelectTrigger>
        <SelectContent>
          {locations.map(location => (
            <SelectItem key={location.id} value={location.id}>
              {location.name}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );
}
